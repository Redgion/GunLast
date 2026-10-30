# GunLast — r4 source and review materials

Mod page: https://www.nexusmods.com/outlast/mods/143

This package contains the eight UnrealScript classes used by the r4 distribution, the installer and launcher scripts as shipped, runtime configuration, compiler configuration references, and the recorded successful build log.

The Nexus upload may use public version 1; r4 is the internal build identifier. The uploader must confirm which uploaded archive is under review. Distribution manifest hashes identify the payload.

## Linux / Fedora / Steam Proton (preview)

See [the Russian installation guide](Linux/README.ru.md) for the Python 3.11+
installer, Steam launch wrapper, recovery/uninstall, payload requirements and
test limits. Run `python3 Linux/gunlast.py doctor` to inspect the installed game.
The installer requires the separate, original M9-r4 `Files` payload and the
Windows Win64 version of Outlast selected through Steam Proton. Native Linux
Outlast is not supported. Installer tests pass on Fedora; in-game Proton support
is **not yet verified**. The tooling archive does not include the missing assets
or compiled script and is not a complete playable release.

## Contents

- UnrealScript/OutlastPistolMod/Classes: all eight mod classes.
- DistributionScripts: original PowerShell and batch sources, Settings.ini, and the payload manifest. They are provided for inspection, not as a standalone installer: this source archive does not contain the Files payload.
- RuntimeConfig: configuration supplied with the mod.
- BuildReference: the SDK engine configurations used for the recorded build and its log. [SDK_ROOT] replaces the author's local directory in the log.
- BUILD_INSTRUCTIONS.md: prerequisites and compilation steps.
- REVIEW_NOTES.md: behavior of the installer, launcher, game code, and asset limitations.
- SOURCE_SHA256.json: integrity hashes for the review materials.

The original compiled script payload SHA-256 is:

dcdf531f66d6c4fbff06dbd27438f6ee9fe23218b929d7f2ce147185d68f7acc

The original M9Assets.OLContent payload SHA-256 is:

2d9b2a88c03e0886961762c6471b95b89603406375b2682572c9f276178ab4fa

These are reference identifiers, not a malware scan or a guarantee that every upload is identical.

Game, UDK, and SDK binaries are not included in this review archive. No blanket license or redistribution permission is granted for third-party game content or M9 assets. See REVIEW_NOTES.md.
