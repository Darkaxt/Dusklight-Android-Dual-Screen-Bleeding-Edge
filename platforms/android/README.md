# Android Shell

This directory contains a minimal SDLActivity-based Android app wrapper for Dusklight.

## Prerequisites

- Android SDK installed (`ANDROID_HOME`)
- Android NDK version used by CMake presets (`ANDROID_NDK_VERSION`)
- JDK 17+

Example:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_NDK_VERSION="29.0.14206865"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
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

## Refresh SDL Java shim (optional)

If you update SDL and want to refresh the embedded Java shim files:

```bash
./android/scripts/sync-sdl-java.sh
```

## Verify an APK

`scripts/android/Verify-AndroidApk.ps1` checks the package, numeric version,
exact ABI set, ZIP and ELF 16 KiB alignment, signature and signer when required,
SHA-256, and the complete APK path set for prohibited game/user payloads.
