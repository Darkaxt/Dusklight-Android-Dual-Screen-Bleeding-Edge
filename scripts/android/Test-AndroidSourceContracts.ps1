[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$javaRoot = Join-Path $repoRoot 'platforms\android\app\src\main\java\com\twilitrealm\dusk'

$activity = Get-Content -LiteralPath (Join-Path $javaRoot 'DuskActivity.java') -Raw
$companion = Get-Content -LiteralPath (Join-Path $javaRoot 'DuskCompanionActivity.java') -Raw
$guide = Get-Content -LiteralPath (Join-Path $javaRoot 'DuskGuideBrowser.java') -Raw
$gradle = Get-Content -LiteralPath (Join-Path $repoRoot 'platforms\android\app\build.gradle') -Raw
$gradleSettings = Get-Content -LiteralPath (Join-Path $repoRoot 'platforms\android\settings.gradle') -Raw
$appInfo = Get-Content -LiteralPath (Join-Path $repoRoot 'src\dusk\app_info.hpp') -Raw
$cmake = Get-Content -LiteralPath (Join-Path $repoRoot 'CMakeLists.txt') -Raw
$adaptedCpp = @(
    Get-Content -LiteralPath (Join-Path $repoRoot 'src\dusk\settings.cpp') -Raw
    Get-Content -LiteralPath (Join-Path $repoRoot 'src\dusk\ui\settings.cpp') -Raw
) -join "`n"
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -notmatch $Pattern) {
        $script:failures.Add($Message)
    }
}

function Reject-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -match $Pattern) {
        $script:failures.Add($Message)
    }
}

Reject-Match $activity 'COMPANION_LAUNCH_TIMEOUT_MS|companionLaunchPendingAt|SystemClock' `
    'Companion launch state must be lifecycle-driven, not timestamp/timeout-driven.'
Require-Match $activity 'private\s+boolean\s+companionLaunchPending\s*;' `
    'DuskActivity must keep an explicit pending-launch lifecycle state.'
Reject-Match $activity 'installStickyImmersive|reHideBars|postDelayed\s*\(' `
    'Immersive mode must use WindowInsetsController lifecycle behavior without delayed retries.'

$combinedDisplayHosts = $activity + "`n" + $companion
Reject-Match $combinedDisplayHosts 'COMPANION_PANEL_[WH]|\b1240\b|\b1080\b' `
    'Companion buffer dimensions must come from the host Display, not Thor constants.'
Require-Match $activity 'static\s+Point\s+companionBufferSize\s*\(\s*Display\s+display\s*\)' `
    'DuskActivity must provide one shared Display-derived companion buffer calculation.'
Require-Match $companion 'DuskActivity\.companionBufferSize\s*\(' `
    'The swapped companion activity must use the shared Display-derived buffer calculation.'

Reject-Match $guide 'if\s*\(\s*attempt\s*>|attempt\s*\+\s*1' `
    'Guide DOM settling must wait for the observed stable state without an attempt deadline.'

$versionManifest = Join-Path $repoRoot 'platforms\android\version.properties'
if (-not (Test-Path -LiteralPath $versionManifest -PathType Leaf)) {
    $failures.Add('Android release identity must be defined in version.properties.')
} else {
    $version = Get-Content -LiteralPath $versionManifest -Raw
    Require-Match $version '(?m)^versionName=2\.0\.2\.1$' `
        'The maintained Android port must use numeric versionName 2.0.2.1.'
    Require-Match $version '(?m)^versionCode=200002001$' `
        'The maintained Android port must use monotonic versionCode 200002001.'
    Require-Match $version '(?m)^releaseTag=2\.0\.2\.1$' `
        'The Git tag must equal the numeric APK versionName.'
}
Require-Match $gradle 'version\.properties' `
    'Gradle must read release identity from the checked-in version manifest.'
Require-Match $gradleSettings 'DUSK_ANDROID_BUILD_ROOT' `
    'Gradle must support a D:-hosted external build root.'
Require-Match $gradle 'DUSK_ANDROID_NATIVE_PROPERTIES' `
    'Gradle must consume the external CMake/Borealis native build contract.'
Require-Match $gradle 'DUSK_ANDROID_RELEASE_ABIS' `
    'Gradle must accept the explicit release ABI contract.'
Require-Match $appInfo 'githubOwner\s*=\s*"Darkaxt"' `
    'The in-app updater must query the maintained Darkaxt repository.'
Require-Match $appInfo 'githubRepo\s*=\s*"Dusklight-Android-Dual-Screen-Bleeding-Edge"' `
    'The in-app updater repository name must match the publication contract.'
Require-Match $cmake 'DUSK_VERSION_REVISION' `
    'CMake must parse the fourth numeric Android release component.'
Require-Match $cmake '100000000' `
    'CMake versionCode must use the monotonic four-component encoding.'
Require-Match $cmake 'FetchContent_Declare\s*\(\s*miniz' `
    'The dual-screen archive helper must declare its miniz dependency.'
Require-Match $adaptedCpp '(?-i:config::save\s*\()' `
    'Adapted dual-screen settings must use the v2 stable-base config::save API.'

if ($failures.Count -ne 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Android source contract failures: $($failures.Count)"
}

Write-Output 'Android source contracts passed.'
