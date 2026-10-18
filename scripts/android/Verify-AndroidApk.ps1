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

function Assert-ArchivePayload {
    param($Archive, [string]$Container)
    foreach ($entry in $Archive.Entries) {
        $name = $entry.FullName.Replace('\', '/').ToLowerInvariant()
        if ($name -match '\.(iso|gcm|rvz|wbfs|ciso|nkit|wia|otr|o2r|z64|n64|v64|gb|gbc|gba|nds|3ds|cia|sav|srm|sra|gci|eep|fla|state|solarus)$' -or
            $name -match '(^|/)(save|saves|texture_packs|texture-packs|guides|roms|games)(/|$)') {
            throw "Forbidden game/personal payload: ${Container}!$($entry.FullName)"
        }
        $stream = $entry.Open()
        try {
            $magic = [byte[]]::new(4)
            $read = $stream.Read($magic, 0, 4)
            if ($read -eq 4 -and $magic[0] -eq 0x50 -and $magic[1] -eq 0x4b -and
                $magic[2] -in @(3, 5, 7) -and $magic[3] -in @(4, 6, 8)) {
                $stream.Dispose()
                $stream = $entry.Open()
                $nested = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read, $true)
                try { Assert-ArchivePayload $nested "${Container}!$($entry.FullName)" }
                finally { $nested.Dispose() }
            }
        } finally { $stream.Dispose() }
    }
}

function Assert-Arm64LoadAlignment {
    param($Entry)
    $reader = [IO.BinaryReader]::new($Entry.Open())
    try {
        $header = $reader.ReadBytes(64)
        if ($header.Length -ne 64 -or [BitConverter]::ToUInt32($header, 0) -ne 0x464c457f -or
            $header[4] -ne 2 -or $header[5] -ne 1 -or [BitConverter]::ToUInt16($header, 18) -ne 183) {
            throw "Invalid arm64 ELF: $($Entry.FullName)"
        }
        $offset = [BitConverter]::ToUInt64($header, 32)
        $size = [BitConverter]::ToUInt16($header, 54)
        $count = [BitConverter]::ToUInt16($header, 56)
        if ($offset -lt 64 -or $size -lt 56 -or $count -eq 0 -or
            ([decimal]$offset + [decimal]$size * $count) -gt $Entry.Length) { throw 'Invalid ELF program headers' }
        $skip = $offset - 64
        while ($skip -gt 0) {
            $chunk = $reader.ReadBytes([int][Math]::Min(16384, $skip))
            if (-not $chunk.Length) { throw 'Truncated ELF program headers' }
            $skip -= $chunk.Length
        }
        $loads = 0
        for ($i = 0; $i -lt $count; $i++) {
            $p = $reader.ReadBytes($size)
            if ($p.Length -ne $size) { throw 'Truncated ELF LOAD segment' }
            if ([BitConverter]::ToUInt32($p, 0) -ne 1) { continue }
            $loads++
            $align = [BitConverter]::ToUInt64($p, 48)
            if ($align -lt 16384 -or ($align -band ($align - 1)) -ne 0 -or
                ([BitConverter]::ToUInt64($p, 8) % 16384) -ne ([BitConverter]::ToUInt64($p, 16) % 16384)) {
                throw "ELF LOAD segment is not 16 KiB aligned: $($Entry.FullName)"
            }
        }
        if (-not $loads) { throw 'ELF has no LOAD segments' }
    } finally { $reader.Dispose() }
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
try {
    Assert-ArchivePayload $archive 'APK'
    foreach ($abi in $ExpectedAbis) {
        $entryName = "lib/$abi/libmain.so"
        $entry = $archive.GetEntry($entryName)
        if (-not $entry) {
            throw "Missing native library: $entryName"
        }
    }
    foreach ($entry in @($archive.Entries | Where-Object FullName -match '^lib/arm64-v8a/[^/]+\.so$')) {
        Assert-Arm64LoadAlignment $entry
    }
}
finally {
    $archive.Dispose()
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
