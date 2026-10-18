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
    [string] $JavaHome = $(if ($env:JAVA_HOME) { $env:JAVA_HOME } else { 'C:\Program Files\Zulu\zulu-21' }),

    [Parameter()]
    [string] $GradleGateLauncher = $(if ($env:DUSK_GRADLE_GATE_LAUNCHER) {
        $env:DUSK_GRADLE_GATE_LAUNCHER
    } else { Join-Path $env:USERPROFILE '.agents\skills\gradle-build-gate\scripts\invoke_gradle_build_gate.py' }),

    [string] $ThreadName
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

# Some native dependencies launch nested CMake/Ninja builds and only propagate
# the generator name. Make the exact SDK-bundled Ninja used above discoverable
# to those child processes as well.
$env:PATH = (Split-Path -Parent $ninja) + [IO.Path]::PathSeparator + $env:PATH

$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
$scratch = Join-Path $resolvedOutput 'scratch'
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$env:TEMP = $scratch
$env:TMP = $scratch
$env:CMAKE_BUILD_PARALLEL_LEVEL = '2'
$env:CARGO_BUILD_JOBS = '2'
$env:GRADLE_USER_HOME = Join-Path $resolvedOutput 'gradle-home'
$jniRoot = Join-Path $resolvedOutput 'jni'
$apkRoot = Join-Path $resolvedOutput 'apk'
New-Item -ItemType Directory -Path $jniRoot, $apkRoot -Force | Out-Null

$auroraSource = Join-Path $SourceRoot 'extern\aurora'
$auroraPatch = Join-Path $SourceRoot 'patches\aurora-dualscreen-v2.0.3.patch'
$auroraOverlay = Join-Path $resolvedOutput 'aurora-source'
$auroraArchive = Join-Path $resolvedOutput 'aurora-source.tar'
foreach ($path in $auroraPatch, (Join-Path $auroraSource 'CMakeLists.txt')) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Aurora source input not found: $path"
    }
}
$auroraCommit = (& git.exe -C $auroraSource rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve exact Aurora source commit' }
$overlayIdentity = "$auroraCommit/$((Get-FileHash -LiteralPath $auroraPatch -Algorithm SHA256).Hash)"
$overlayMarker = Join-Path $resolvedOutput 'aurora-overlay.identity'
if (Test-Path -LiteralPath $auroraOverlay) {
    if (-not (Test-Path -LiteralPath $overlayMarker) -or
        (Get-Content -LiteralPath $overlayMarker -Raw).Trim() -ne $overlayIdentity) {
        throw 'Existing Aurora overlay has another identity. Use a fresh task-owned output root; clean old outputs through transactional cleanup.'
    }
} else {
New-Item -ItemType Directory -Path $auroraOverlay -Force | Out-Null
Invoke-Checked -Program 'git.exe' -Arguments @(
    '-C', $auroraSource, 'archive', '--format=tar', "--output=$auroraArchive", 'HEAD')
Invoke-Checked -Program 'tar.exe' -Arguments @('-xf', $auroraArchive, '-C', $auroraOverlay)
Invoke-Checked -Program 'git.exe' -Arguments @(
    '-C', $auroraOverlay, 'apply', '--no-index', $auroraPatch)
Set-Content -LiteralPath $overlayMarker -Value $overlayIdentity
}
foreach ($path in 'include\dolphin\arq.h', 'include\aurora\aux_window.hpp') {
    if (-not (Test-Path -LiteralPath (Join-Path $auroraOverlay $path) -PathType Leaf)) {
        throw "Patched Aurora overlay is incomplete: $path"
    }
}

$targets = @(
    @{ Abi = 'arm64-v8a'; Rust = 'aarch64-linux-android'; Release = $true }
)
$releaseNativeBuildDir = $null

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
        # The stable Android export generator scans ELF objects before linking.
        # Forcing IPO produces LLVM bitcode that symgen cannot inspect. Match
        # the official Android preset rather than bypassing its mod ABI scan.
        '-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF',
        '-DBUILD_SHARED_LIBS=OFF',
        '-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON',
        '-DCMAKE_DISABLE_FIND_PACKAGE_zstd=ON',
        '-DDUSK_ENABLE_SENTRY_NATIVE=OFF',
        "-DDUSK_VERSION_OVERRIDE=$($version.versionName)",
        "-DDUSK_AURORA_SOURCE_DIR=$auroraOverlay",
        "-DRust_CARGO_TARGET=$($target.Rust)"
    )
    Invoke-Checked -Program $cmake -Arguments @('--build', $buildDir, '--target', 'dusklight', '--config', 'Release', '--parallel', '2')
    $library = Join-Path $buildDir 'libmain.so'
    if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
        throw "Native output was not produced: $library"
    }
    if ($target.Release) {
        $releaseNativeBuildDir = $buildDir
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
$env:DUSK_ANDROID_NATIVE_BUILD_DIR = $releaseNativeBuildDir
$env:DUSK_ANDROID_NATIVE_PROPERTIES = Join-Path $releaseNativeBuildDir 'borealis-android.properties'
$env:DUSK_VERSION = $version.versionName
$env:DUSK_VERSION_CODE = $version.versionCode
$env:GIT_TAG = $version.releaseTag
$androidProject = Join-Path $SourceRoot 'platforms\android'
    if (-not (Test-Path -LiteralPath $GradleGateLauncher -PathType Leaf)) {
        throw "Gradle build-gate launcher does not exist: $GradleGateLauncher"
    }
    $gateArguments = @(
        $GradleGateLauncher,
        'run',
        '--project', $androidProject,
        '--owner-task', 'Dusklight stable dual-screen release build'
    )
    if ($ThreadName) { $gateArguments += @('--thread-name', $ThreadName) }
    $gateArguments += @('--', ':app:assembleRelease')
    Invoke-Checked -Program 'python.exe' -Arguments $gateArguments

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
