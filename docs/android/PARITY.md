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
- [ ] Arm64 release compilation, signature, payload and 16-KiB verification.

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
- [ ] Exact official Aurora plus versioned overlay compared against the newest
  reference Aurora tree and verified by release compilation.

Device behavior validation is pending by the updater's explicit no-device contract.
Unchecked build gates must pass before source or APK publication.
