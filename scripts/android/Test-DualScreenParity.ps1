param([string]$Reference = 'edaf1f405ee8477d2074c36a3fbf0a32aade75c0')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$changes = @(& git -C $root diff --ignore-space-at-eol --name-only $Reference -- src include)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect pinned reference parity' }
# Deliberate maintained-repository update routing and numeric-version support.
$allowed = @('src/dusk/app_info.hpp', 'src/dusk/release_version.cpp',
    'src/dusk/release_version.hpp', 'src/dusk/update_check.cpp')
$unexpected = @($changes | Where-Object { $_ -notin $allowed })
if ($unexpected.Count) { throw "Unreviewed gameplay/dual-screen deviation: $($unexpected -join ', ')" }
Write-Output 'Gameplay and companion source parity passed against the exact dual-screen reference (line endings ignored; only documented updater deviations).'
