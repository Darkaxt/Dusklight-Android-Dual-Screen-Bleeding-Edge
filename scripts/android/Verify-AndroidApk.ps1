[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ApkPath,

    [Parameter(Mandatory)]
    [string] $ExpectedPackage,

    [Parameter(Mandatory)]
    [string] $ExpectedVersionName,

    [Parameter(Mandatory)]
    [long] $ExpectedVersionCode,

    [Parameter()]
    [string[]] $ExpectedAbis = @('arm64-v8a'),

    [Parameter()]
    [string] $ExpectedSignerSha256,

    [Parameter()]
    [switch] $AllowUnsigned,

    [Parameter()]
    [string] $AndroidSdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }),

    [Parameter()]
    [string] $NdkVersion = '29.0.14206865'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-NewestBuildTool {
    param([Parameter(Mandatory)][string] $Name)
    $root = Join-Path $AndroidSdk 'build-tools'
    $candidate = Get-ChildItem -LiteralPath $root -Directory |
        Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
        ForEach-Object { Join-Path $_.FullName $Name } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if (-not $candidate) {
        throw "Android build tool not found: $Name"
    }
    return $candidate
}

function Invoke-Captured {
    param([string] $Program, [string[]] $Arguments, [switch] $AcceptFailure)
    $output = & $Program @Arguments 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    if (-not $AcceptFailure -and $code -ne 0) {
        throw "Command failed with exit code ${code}: $Program`n$($output -join [Environment]::NewLine)"
    }
    return [pscustomobject]@{ ExitCode = $code; Lines = @($output) }
}

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$aapt = Resolve-NewestBuildTool -Name 'aapt.exe'
$zipalign = Resolve-NewestBuildTool -Name 'zipalign.exe'
$apksigner = Resolve-NewestBuildTool -Name 'apksigner.bat'
$readelf = Join-Path $AndroidSdk "ndk\$NdkVersion\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe"
if (-not (Test-Path -LiteralPath $readelf -PathType Leaf)) {
    throw "LLVM readelf not found: $readelf"
}

$badging = (Invoke-Captured -Program $aapt -Arguments @('dump', 'badging', $resolvedApk)).Lines
$packageLine = $badging | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
if ($packageLine -notmatch "name='([^']+)'" -or $Matches[1] -ne $ExpectedPackage) {
    throw "Unexpected package identity: $packageLine"
}
if ($packageLine -notmatch "versionCode='([^']+)'" -or [long]$Matches[1] -ne $ExpectedVersionCode) {
    throw "Unexpected versionCode: $packageLine"
}
if ($packageLine -notmatch "versionName='([^']+)'" -or $Matches[1] -ne $ExpectedVersionName) {
    throw "Unexpected versionName: $packageLine"
}
$nativeLine = $badging | Where-Object { $_ -like 'native-code:*' } | Select-Object -First 1
$actualAbis = @([regex]::Matches([string]$nativeLine, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
if ((Compare-Object -ReferenceObject @($ExpectedAbis | Sort-Object) -DifferenceObject @($actualAbis | Sort-Object))) {
    throw "Unexpected native ABI set: $($actualAbis -join ', ')"
}

Invoke-Captured -Program $zipalign -Arguments @('-c', '-P', '16', '-v', '4', $resolvedApk) | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedApk)
$temporaryRoot = Join-Path 'D:\Temp' ("dusklight-apk-verify-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $forbiddenExtensions = @('.iso', '.gcm', '.rvz', '.wbfs', '.ciso', '.nkit', '.wia', '.otr', '.o2r', '.sav', '.srm', '.gci')
    $forbiddenSegments = @('save', 'saves', 'texture_packs', 'texture-packs', 'guides', 'roms', 'games')
    $payloadViolations = @()
    foreach ($entry in $archive.Entries) {
        $normalized = $entry.FullName.Replace('\', '/').ToLowerInvariant()
        $extension = [IO.Path]::GetExtension($normalized)
        $segments = @($normalized.Split('/', [StringSplitOptions]::RemoveEmptyEntries))
        if ($forbiddenExtensions -contains $extension -or ($segments | Where-Object { $forbiddenSegments -contains $_ })) {
            $payloadViolations += $entry.FullName
        }
    }
    if ($payloadViolations.Count -gt 0) {
        throw "Forbidden copyrighted or personal payload entries found: $($payloadViolations -join ', ')"
    }

    foreach ($abi in $ExpectedAbis) {
        $entryName = "lib/$abi/libmain.so"
        $entry = $archive.GetEntry($entryName)
        if (-not $entry) {
            throw "Missing native library: $entryName"
        }
        $destination = Join-Path $temporaryRoot ("libmain-$abi.so")
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
        $programHeaders = (Invoke-Captured -Program $readelf -Arguments @('-lW', $destination)).Lines
        $loadHeaders = @($programHeaders | Where-Object { $_ -match '^\s*LOAD\s+' })
        if ($loadHeaders.Count -eq 0) {
            throw "No ELF LOAD segments found for $abi."
        }
        foreach ($header in $loadHeaders) {
            if ($header -notmatch '\s0x([0-9a-fA-F]+)\s*$' -or [Convert]::ToInt64($Matches[1], 16) -lt 0x4000) {
                throw "ELF LOAD segment is not 16 KiB aligned for ${abi}: $header"
            }
        }
    }
}
finally {
    $archive.Dispose()
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
}

$signature = Invoke-Captured -Program $apksigner -Arguments @('verify', '--verbose', '--print-certs', $resolvedApk) -AcceptFailure
$signerSha256 = $null
if ($signature.ExitCode -eq 0) {
    $digestLine = $signature.Lines | Where-Object { $_ -match 'certificate SHA-256 digest:\s*([0-9a-fA-F]+)' } | Select-Object -First 1
    if (-not $digestLine) {
        throw 'APK signature verified, but no signer SHA-256 digest was reported.'
    }
    $digestLine -match 'certificate SHA-256 digest:\s*([0-9a-fA-F]+)' | Out-Null
    $signerSha256 = $Matches[1].ToLowerInvariant()
    if ($ExpectedSignerSha256 -and $signerSha256 -ne $ExpectedSignerSha256.ToLowerInvariant()) {
        throw "Unexpected signer certificate SHA-256: $signerSha256"
    }
}
elseif (-not $AllowUnsigned) {
    throw "APK signature verification failed:`n$($signature.Lines -join [Environment]::NewLine)"
}

$hash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToLowerInvariant()
[pscustomobject]@{
    ApkPath = $resolvedApk
    Package = $ExpectedPackage
    VersionName = $ExpectedVersionName
    VersionCode = $ExpectedVersionCode
    Abis = $actualAbis
    ZipAligned16KiB = $true
    ElfLoadAligned16KiB = $true
    Signed = ($signature.ExitCode -eq 0)
    SignerSha256 = $signerSha256
    Sha256 = $hash
    PayloadScan = 'clean'
} | ConvertTo-Json -Depth 3
