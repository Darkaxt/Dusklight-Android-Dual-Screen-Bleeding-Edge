# Three-level source and host verification checklist

Target: official `v2.0.3` / `40457c6adb381928e4b5fef6ed459ed291edd5e2`;
reference `v2.0.3-ds-3.0.3` / `edaf1f405ee8477d2074c36a3fbf0a32aade75c0`.
This checklist records source/host evidence, not unperformed device testing.

## 1. Official stable behavior

- [x] Exact official stable ancestry; official Aurora `3227d76` and Borealis
  `4ac5e705` pins retained. The Android and dual-screen adaptation commits remain
  distinct above that base.
- [x] Gameplay and companion `src`/`include` content equals the exact reference
  after ignoring line endings, except the documented maintained-repository update
  routing and numeric-release parser (`Test-DualScreenParity.ps1`).
- [x] GuideConvert and ReleaseVersion host tests pass. The optional personal
  saved-page test is intentionally skipped; synthetic guide fixtures pass.

## 2. Android platform behavior

- [x] Immersive system-bar handling is lifecycle-based without delayed retries.
- [x] Companion launch/teardown state is lifecycle-driven, not an elapsed deadline.
- [x] Both normal and swapped companion buffers derive dimensions from Display.
- [x] Folder selection, ROM handling, configuration and save-path identity remain
  preserved; no user data is bundled or moved by this update.
- [x] Android source contracts check these deliberate platform adaptations.
- [x] Arm64 release compilation, signature, payload and 16-KiB verification.

## 3. Complete reference dual-screen behavior

The source parity check covers every gameplay/companion implementation, not just
selected named functions. Each item below is source-integrated:

- [x] Wii U and 3DS layouts; clean top display; lower HUD and touch controls.
- [x] Field/dungeon maps, items, equipment, collection and offline-guide browsing.
- [x] Forms, transformation hit areas and Ooccoo; silent underwater availability
  polling and no pre-unlock transformation taps.
- [x] Dimming, animation, screen swap, controllers/remapping and settings.
- [x] Null-safe floor face when leaving a dungeon map.
- [x] Phone companion queued sends, socket ownership and disconnect input release.
- [x] Single upstream shader-compilation setting, disabled by default.
- [x] Exact official Aurora plus versioned overlay compared against the newest
  reference Aurora tree and verified by release compilation.

Device behavior validation is pending by the updater's explicit no-device contract.
All listed host gates passed for compiled source
`6255653f08aab60d45afeaf2716757e40a8d1acb`, version `2.0.3.1` / code `200003001`.
The complete Android build explicitly enables both phone-companion flags and
packages all three official bundled mods (`luau_runtime`, `cosmetics`,
`randomizer`). Both APK-root libraries and native libraries inside mod archives
passed ELF LOAD 16-KiB verification; the recursive payload scan passed.

Gradle gate `6b6b97e83cca49bfbcee2171d8199b34` reported build/helper exit 0 and
verified daemon exit. Effective workers=2, no parallel projects, Gradle heap=3GiB;
there were no Kotlin sources or forked Gradle test tasks. Native Ninja actually
used `-j 2`, compiler pools depth=2 and linker depth=1; Cargo was limited to 2 jobs.
The initial legacy forced-IPO setting was removed because stable symgen requires
native ELF input objects, and the exact native NDK version is forwarded to
Borealis Gradle. No official export/mod-ABI step was bypassed.

APK SHA-256: `0d05e42e9fbe430aad358bbfb5c66e8140c48f1a132a79004aaa141240555611`.
Persistent signer: `41f77566128bdee40fd94cbac5cdb14fb1c9d7f20cf0b671b511f5247363e863`.
