<div align="center">
  <img src="res/logo.png" alt="Logo" width="640">

  <p align="center">
    <a href="https://twilitrealm.dev">Official Website</a>
    •
    <a href="https://discord.gg/6NpMhefCK9">Discord</a>
  </p>
</div>

# Android Dual-Screen Bleeding Edge

[![Track upstream releases](https://github.com/Darkaxt/Dusklight-Android-Dual-Screen-Bleeding-Edge/actions/workflows/upstream-tracking.yml/badge.svg)](https://github.com/Darkaxt/Dusklight-Android-Dual-Screen-Bleeding-Edge/actions/workflows/upstream-tracking.yml)

This repository is an **unofficial Android dual-screen port**. It is based on
the official Dusklight `v2.0.2` release and adapts the dual-screen work from
igawa6's `v2.0.0-ds-3.0.2` release. It is not produced, supported, or endorsed by
TwilitRealm or igawa6.

The Android build can move the HUD, map, items, collection screens, guide, and
touch controls to a companion display. Wii U-style and Nintendo 3DS-style
layouts, display swapping, per-display dimming, animation, controller actions,
and ordinary Dusklight save behavior are preserved. The companion surface uses
the real secondary-display dimensions instead of assuming a particular device.

See [Android provenance](docs/android/PROVENANCE.md) for the exact commits,
deliberate integration changes, version identity, and verification contract.

## Upstream sources and updates

| Source | Role |
| --- | --- |
| [TwilitRealm/dusklight](https://github.com/TwilitRealm/dusklight) | Authoritative official stable gameplay base |
| [igawa6/dusklight](https://github.com/igawa6/dusklight) | Android dual-screen feature and UX reference |

This standalone repository combines those two sources. The
[upstream tracking workflow](https://github.com/Darkaxt/Dusklight-Android-Dual-Screen-Bleeding-Edge/actions/workflows/upstream-tracking.yml)
checks their latest non-draft, non-prerelease releases daily at 06:25 UTC and
whenever the integrated provenance changes. It compares exact tags and commits,
maintains one [tracking issue](https://github.com/Darkaxt/Dusklight-Android-Dual-Screen-Bleeding-Edge/issues?q=is%3Aissue%20%22Upstream%20release%20integration%22),
and closes it when both sources match. A green workflow badge means the check
succeeded; its run summary and tracking issue show whether integration is pending.

The local weekly Native Android updater integrates updates, tests and builds the
Android port, preserves its signing identity, and publishes verified APKs here.
The public tracking workflow does not automatically merge code or hold signing
credentials. Source updates must also update `docs/android/PROVENANCE.md` after
verification; it is the tracking workflow's record of what has been integrated.

# Overview

Dusklight is a reverse-engineered reimplementation of Twilight Princess.

It aims to be as accurate as possible to the original while also providing new options, enhancements, and tools to customize your experience.

# Setup

> [!IMPORTANT]
> Dusklight does *not* provide any copyrighted assets. You must provide your own copy of the original game.

> [!IMPORTANT]
> At a minimum, Dusklight requires a GPU with support for either D3D12, Vulkan, or Metal. Your experience with specific hardware, operating systems, and drivers may vary. In particular, older Intel iGPUs have a high likelihood of incompatibility. We are also aware of a number of issues on devices with Adreno GPUs and are working to resolve them.

### 1. Dump your game

You must dump your own copy of the game, please see [this article](https://wiki.dolphin-emu.org/index.php?title=Ripping_Games) for instructions. After dumping, you can use a program like [Dolphin](https://dolphin-emu.org/) or [nodtool](https://github.com/encounter/nod/releases) to convert the `.iso` to a `.rvz` to save space.

Currently, only the GameCube USA and EUR releases are supported. Support for other versions of the game is planned in the future.

### 2. Download [Dusklight](https://github.com/TwilitRealm/dusklight/releases)

### 3. Setup the game
**Windows / macOS / Linux**
- Extract the .zip file
- Launch Dusklight
- Press **Select Disc Image** and provide the path to your supported game dump
- Press **Play**!

**iOS**
- Follow the [iOS setup guide](docs/ios-install-altstore.md)

**Android**
- Install the Dusklight APK
- Launch Dusklight
- Press **Select Disc Image** and provide the path to your supported game dump
- Press **Play**!

The port accepts user-owned GameCube USA or EUR `.iso` and `.rvz` dumps, as the
official project does. No game image, save, texture pack, or downloaded guide is
included in the source tree or release APK.

> [!WARNING]
> Version `1.4.1.1` established the persistent signing identity used by this
> unofficial package. Android will not treat an installation signed by another
> project as an in-place update even though the package name is unchanged.
> Preserve your saves and uninstall the differently signed build before the
> one-time migration. Later releases from this repository can update normally.

# Building

If you'd like to build Dusklight from source, please read the [build instructions](docs/building.md).

Pull requests are welcomed! Note that we do not accept contributions that are primarily AI-generated and will close your PR if we suspect as much. Please also see the [code conventions](docs/code-conventions.md).

# Credits

Special thanks to the [TP decompilation](https://github.com/zeldaret/tp) team, the GC/Wii decompilation community, the [Aurora](https://github.com/encounter/aurora) developers, the [TP speedrunning community](https://zsrtp.link), and all [contributors](https://github.com/TwilitRealm/dusklight/graphs/contributors).

<br/>
<div align="center">
    <a href="https://github.com/encounter/aurora">
        <img src="assets/aurora-powered.png" alt="Powered by Aurora" width="800">
    </a>
</div>
