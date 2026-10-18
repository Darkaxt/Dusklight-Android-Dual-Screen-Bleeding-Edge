# Android Dual-Screen Provenance

## Source identities

- Official stable base: [TwilitRealm/dusklight `v2.0.3`](https://github.com/TwilitRealm/dusklight/releases/tag/v2.0.3), commit `40457c6adb381928e4b5fef6ed459ed291edd5e2`.
- Dual-screen feature reference: [igawa6/dusklight `v2.0.3-ds-3.0.3`](https://github.com/igawa6/dusklight/releases/tag/v2.0.3-ds-3.0.3), commit `edaf1f405ee8477d2074c36a3fbf0a32aade75c0`.
- Android platform layer: commit `4f9898dfd2`, applied directly above the official stable base.
- Dual-screen adaptation layer: commit `45b182473e`, applied above the Android platform layer.
- Aurora base: official commit `3227d76c60e1e782ca576610bce61c9e7744d8be`, with the reviewed dual-screen delta carried by `patches/aurora-dualscreen-v2.0.3.patch` during Android builds.

Those were the newest non-draft, non-prerelease releases in their respective
repositories when revalidated through the authenticated GitHub API on
2026-10-18. The layers remain separate in history so the Android shell and the
adapted gameplay feature set can be reviewed independently.

The reference's five follow-up commits (`ef4bed123e`, `d68953ee25`,
`39b266c223`, `fb00a7f9c4`, `edaf1f405e`) are carried without changes to their
gameplay/companion code: underwater polling is silent, unavailable transformation
buttons cannot retain hit areas, dungeon floor faces are null-safe, phone sends
are queued without holding the client lock across network writes, disconnects
clear held input, and only upstream's shader compilation setting remains.

## Adaptation boundary

The dual-screen implementation is adapted to the stable `v2.0.3` APIs rather
than replacing the base with the reference fork. It covers companion HUD, map,
items, collection, guide, touch interaction, Wii U/3DS layout choices, display
swap and dim controls, animation controls, controller bindings, Ooccoo/form
state, and display-specific overlay behavior.

The Android integration deliberately differs from the reference in three ways:

1. companion launch state follows the activity result instead of a five-second
   clock deadline;
2. secondary rendering derives its buffer size from the actual display instead
   of a hard-coded 1240 by 1080 surface;
3. guide capture waits for the browser's observed settle state without an
   attempt-count cancellation race.

The startup update check targets this repository while the unchanged
`TwilitRealm` organization identifier continues to own the existing on-device
paths and saves. This avoids silently moving user data.

## Release identity and payload

The current port release is `2.0.3.1`, with Android `versionCode` `200003001`.
Numeric four-component tags are intentional: the first three fields identify
the official stable base and the fourth is this port's monotonic revision.
Descriptive wording belongs in the release title, not the update-comparison
identity.

The public APK contains only `arm64-v8a`, matching the production ABI selected
by both source releases and their Android release workflows. The arm64 APK and
every ELF `LOAD` segment are verified for 16 KiB alignment.

Dusklight requires the user to supply a legally obtained GameCube USA or EUR
disc dump in `.iso` or `.rvz` form. The repository and release contain no game
image, save data, texture pack, cached guide page, or other copyrighted game
payload. Release verification scans all APK paths, including nested asset paths,
for those payload classes.

## Signing and migration

The APK is normalized and signed by the shared Native Android signing worker
under the package-specific persistent certificate
`41f77566128bdee40fd94cbac5cdb14fb1c9d7f20cf0b671b511f5247363e863`.
Its pinned certificate digest and the release SHA-256 are published with the
release and rechecked after an authenticated API download.

Because Android requires matching signatures for an in-place update, users of a
differently signed build must preserve their saves, uninstall that build, and
install this one once. Releases from this repository reuse the same signer and
can subsequently update normally.
