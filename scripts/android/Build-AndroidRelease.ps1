[CmdletBinding()]
param(
    [Parameter()]
    [string] $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

    [Parameter(Mandatory)]
    [string] $OutputRoot,

    [Parameter()]
    [string] $AndroidSdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }),

    [Parameter()]
    [string] $NdkVersion = '29.0.14206865',

    [Parameter()]
    [string] $JavaHome = $(if ($env:JAVA_HOME) { $env:JAVA_HOME } else { 'C:\Program Files\Zulu\zulu-21' })
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string] $Program,
        [Parameter(Mandatory)][string[]] $Arguments
    )
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Program"
    }
}

$versionFile = Join-Path $SourceRoot 'platforms\android\version.properties'
$version = @{}
foreach ($line in Get-Content -LiteralPath $versionFile) {
    if ($line -match '^([^#=]+)=(.*)$') {
        $version[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}
foreach ($required in 'versionName', 'versionCode', 'releaseTag') {
    if (-not $version.ContainsKey($required)) {
        throw "Missing $required in $versionFile"
    }
}
if ($version.releaseTag -ne $version.versionName) {
    throw 'Release tag and version name must be identical.'
}

$cmake = Join-Path $AndroidSdk 'cmake\3.31.5\bin\cmake.exe'
$ninja = Join-Path $AndroidSdk 'cmake\3.31.5\bin\ninja.exe'
$toolchain = Join-Path $AndroidSdk "ndk\$NdkVersion\build\cmake\android.toolchain.cmake"
$strip = Join-Path $AndroidSdk "ndk\$NdkVersion\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"
$gradle = Join-Path $SourceRoot 'platforms\android\gradlew.bat'
foreach ($path in $cmake, $ninja, $toolchain, $strip, $gradle, (Join-Path $JavaHome 'bin\java.exe')) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required build tool not found: $path"
    }
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
$jniRoot = Join-Path $resolvedOutput 'jni'
$apkRoot = Join-Path $resolvedOutput 'apk'
New-Item -ItemType Directory -Path $jniRoot, $apkRoot -Force | Out-Null

$targets = @(
    @{ Abi = 'arm64-v8a'; Rust = 'aarch64-linux-android'; Release = $true }
)

foreach ($target in $targets) {
    Invoke-Checked -Program 'rustup.exe' -Arguments @('target', 'add', $target.Rust)
    $buildDir = Join-Path $resolvedOutput ("native-" + $target.Abi)
    Invoke-Checked -Program $cmake -Arguments @(
        '-S', $SourceRoot,
        '-B', $buildDir,
        '-G', 'Ninja',
        "-DCMAKE_MAKE_PROGRAM=$ninja",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
        "-DANDROID_ABI=$($target.Abi)",
        '-DANDROID_PLATFORM=android-28',
        '-DCMAKE_BUILD_TYPE=Release',
        '-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON',
        '-DBUILD_SHARED_LIBS=OFF',
        '-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON',
        '-DCMAKE_DISABLE_FIND_PACKAGE_zstd=ON',
        '-DDUSK_ENABLE_SENTRY_NATIVE=OFF',
        "-DDUSK_VERSION_OVERRIDE=$($version.versionName)",
        "-DRust_CARGO_TARGET=$($target.Rust)"
    )
    Invoke-Checked -Program $cmake -Arguments @('--build', $buildDir, '--target', 'dusklight', '--config', 'Release')
    $library = Join-Path $buildDir 'libmain.so'
    if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
        throw "Native output was not produced: $library"
    }
    if ($target.Release) {
        $abiDir = Join-Path $jniRoot $target.Abi
        New-Item -ItemType Directory -Path $abiDir -Force | Out-Null
        $stagedLibrary = Join-Path $abiDir 'libmain.so'
        Copy-Item -LiteralPath $library -Destination $stagedLibrary -Force
        Invoke-Checked -Program $strip -Arguments @('--strip-unneeded', $stagedLibrary)
    }
}

$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:JAVA_HOME = $JavaHome
$env:DUSK_ANDROID_BUILD_ROOT = Join-Path $resolvedOutput 'gradle'
$env:DUSK_ANDROID_JNI_LIBS_DIR = $jniRoot
$env:DUSK_ANDROID_RELEASE_ABIS = 'arm64-v8a'
$env:DUSK_VERSION = $version.versionName
$env:DUSK_VERSION_CODE = $version.versionCode
$env:GIT_TAG = $version.releaseTag
$androidProject = Join-Path $SourceRoot 'platforms\android'
Invoke-Checked -Program $gradle -Arguments @('--no-daemon', '-p', $androidProject, ':app:assembleRelease')

$gradleApkRoot = Join-Path $env:DUSK_ANDROID_BUILD_ROOT 'app\outputs\apk\release'
$unsignedApks = @(Get-ChildItem -LiteralPath $gradleApkRoot -Filter '*-unsigned.apk' -File)
if ($unsignedApks.Count -ne 1) {
    throw "Expected exactly one unsigned release APK in $gradleApkRoot; found $($unsignedApks.Count)."
}
$outputApk = Join-Path $apkRoot ("Dusklight-Android-Dual-Screen-Bleeding-Edge-$($version.versionName)-unsigned.apk")
Copy-Item -LiteralPath $unsignedApks[0].FullName -Destination $outputApk -Force

[pscustomobject]@{
    ApkPath = $outputApk
    VersionName = $version.versionName
    VersionCode = [int64]$version.versionCode
    ReleaseAbis = @('arm64-v8a')
    CompileCheckedAbis = @('arm64-v8a')
} | ConvertTo-Json -Depth 3
