$verifier = Join-Path $PSScriptRoot '..\Verify-AndroidApk.ps1'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($verifier, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw $errors[0] }
foreach ($name in @('Assert-ArchivePayload', 'Assert-Arm64LoadAlignment')) {
    $function = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
    . ([scriptblock]::Create($function.Extent.Text))
}
Add-Type -AssemblyName System.IO.Compression
function New-ArchiveBytes([string]$Name, [byte[]]$Bytes) {
    $memory = [IO.MemoryStream]::new()
    $archive = [IO.Compression.ZipArchive]::new($memory, 'Create', $true)
    $stream = $archive.CreateEntry($Name).Open()
    $stream.Write($Bytes, 0, $Bytes.Length); $stream.Dispose(); $archive.Dispose()
    $result = $memory.ToArray(); $memory.Dispose(); return ,$result
}
function Test-PayloadRejected([byte[]]$Bytes) {
    $memory = [IO.MemoryStream]::new($Bytes)
    $archive = [IO.Compression.ZipArchive]::new($memory, 'Read')
    try { Assert-ArchivePayload $archive 'fixture'; return $false }
    catch { return $true }
    finally { $archive.Dispose(); $memory.Dispose() }
}
function Test-ElfRejected([uint64]$Alignment) {
    $bytes = [byte[]]::new(120)
    [BitConverter]::GetBytes([uint32]0x464c457f).CopyTo($bytes, 0)
    $bytes[4] = 2; $bytes[5] = 1
    [BitConverter]::GetBytes([uint16]183).CopyTo($bytes, 18)
    [BitConverter]::GetBytes([uint64]64).CopyTo($bytes, 32)
    [BitConverter]::GetBytes([uint16]56).CopyTo($bytes, 54)
    [BitConverter]::GetBytes([uint16]1).CopyTo($bytes, 56)
    [BitConverter]::GetBytes([uint32]1).CopyTo($bytes, 64)
    [BitConverter]::GetBytes($Alignment).CopyTo($bytes, 112)
    $memory = [IO.MemoryStream]::new((New-ArchiveBytes 'lib/arm64-v8a/libmain.so' $bytes))
    $archive = [IO.Compression.ZipArchive]::new($memory, 'Read')
    try { Assert-Arm64LoadAlignment $archive.Entries[0]; return $false }
    catch { return $true }
    finally { $archive.Dispose(); $memory.Dispose() }
}
Describe 'Android release payload and ELF contracts' {
    It 'rejects a raw game image' { (Test-PayloadRejected (New-ArchiveBytes 'assets/game.rvz' ([byte[]]@(1)))) | Should Be $true }
    It 'rejects a raw ROM hidden inside a generically named nested archive' {
        $inner = New-ArchiveBytes 'games/private.iso' ([byte[]]@(1))
        (Test-PayloadRejected (New-ArchiveBytes 'assets/module.bin' $inner)) | Should Be $true
    }
    It 'allows ordinary nested engine assets' {
        $inner = New-ArchiveBytes 'module.json' ([byte[]]@(123, 125))
        (Test-PayloadRejected (New-ArchiveBytes 'assets/module.dusk' $inner)) | Should Be $false
    }
    It 'rejects 4 KiB native LOAD alignment' { (Test-ElfRejected 4096) | Should Be $true }
    It 'accepts 16 KiB native LOAD alignment' { (Test-ElfRejected 16384) | Should Be $false }
}
