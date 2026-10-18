# Android Shell

This directory contains the Borealis/SDL Android app wrapper for Dusklight.

## Prerequisites

- Android SDK installed (`ANDROID_HOME`)
- Android NDK version used by CMake presets (`ANDROID_NDK_VERSION`)
- JDK 21

Example:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_NDK_VERSION="29.0.14206865"
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
```

## Reproducible release build (Windows)

```powershell
.\scripts\android\Build-AndroidRelease.ps1 `
  -OutputRoot D:\Temp\dusklight-release
```

The script keeps native, Gradle, JNI-staging, and APK outputs outside the source
tree. It compiles the exact production ABI, `arm64-v8a`, and derives the numeric
identity from `version.properties`.
The output remains unsigned until it passes the shared signing worker's
Normalize gate.

Desktop Gradle execution requires the installed shared build-gate launcher (the
default user-profile path, or `DUSK_GRADLE_GATE_LAUNCHER`). Native Ninja and Cargo
are explicitly limited to two jobs. Pass the current chat title with `-ThreadName`
when available. Reusing an output root is allowed only for the same Aurora overlay
identity; use a new exact D:/Temp root after a source/patch change and retire old
outputs through transactional cleanup after verification.

The pure GuideConvert/ReleaseVersion host tests can be configured with
`cmake -S tests -B D:\Temp\dusklight-tests`, built with `--parallel 2`, and run
with `ctest --test-dir D:\Temp\dusklight-tests -C Release --output-on-failure`.

## Refresh SDL Java shim (optional)

If you update SDL and want to refresh the embedded Java shim files:

```bash
./android/scripts/sync-sdl-java.sh
```

## Verify an APK

`scripts/android/Verify-AndroidApk.ps1` checks the package, numeric version,
exact ABI set, ZIP and ELF 16 KiB alignment, signature and signer when required,
SHA-256, and the complete APK path set for prohibited game/user payloads.
