# Building the GunLast r4 script package

## Prerequisites

- Windows.
- A legitimately obtained Outlast installation.
- UDK July 2013 (the recorded compiler reports engine version 10907; compiled July 1, 2013).
- The Outlast-Level-Editor project by superboo07:
  https://github.com/superboo07/Outlast-Level-Editor

Follow that project's README to install UDK separately and copy its Binaries folder into the SDK project. The SDK supplies the Outlast class declarations and engine dependencies. Stock UDK by itself is insufficient for this package.

The external SDK's exact Git revision was not recorded for the original build. BuildReference contains the engine configurations used locally; compilation has not been repeated from a fresh external SDK checkout for this review package. It is not claimed to be a byte-reproducible build environment.

## Compile

1. Work in a separate SDK checkout, not the retail game folder. Call its root SDK_ROOT below.
2. Copy the eight .uc files from UnrealScript/OutlastPistolMod/Classes into:
   SDK_ROOT\Development\Src\OutlastPistolMod\Classes
3. In SDK_ROOT\UDKGame\Config\DefaultEngine.ini and the generated UDKEngine.ini, ensure that OLGame is in EditPackages and OutlastPistolMod is the last mod package. The recorded configuration contains these entries, in this order:

   +EditPackages=OLGame
   +ModEditPackages=OLCustomPlayerModelSDK
   +ModEditPackages=SpeedrunHelper
   +ModEditPackages=SHModifiers
   +ModEditPackages=TAS
   +ModEditPackages=OutlastPistolMod

   Refer to BuildReference/DefaultEngine.ini and UDKEngine.ini for the full recorded settings. Preserve SDK paths appropriate to your checkout. Remove stale package entries only when their source packages do not exist. The original environment removed entries for HUDWidgetSystem, RichPresence, Test, OnlineSubsystemGameSpy, and OnlineSubsystemLive. They are not required by GunLast.
4. Open a terminal in SDK_ROOT and run:

   Binaries\Win32\UDK.com make -unattended -nopause

5. Require a successful exit and the message:

   Success - 0 error(s), 0 warning(s)

6. The compiler writes:

   SDK_ROOT\UDKGame\Script\OutlastPistolMod.u

7. For the retail mod layout, copy those bytes into:

   Files\Custom\OutlastPistolMod\Content\OutlastPistolMod.OLScript

   This packaging step changes the filename extension; it does not encrypt, pack, or transform the compiled code. Do not leave older copies of OutlastPistolMod.u in the retail CookedPCConsole root, since they can shadow the new mod package.

## Other distributed files

The .cmd, .bat, .ps1 and .ini files are distributed as readable text and do not have a compilation step.

M9Assets.OLContent is a pre-existing Unreal asset package containing models and audio. Its editable source project and asset authorship/license records were not supplied with the working mod. This source bundle cannot rebuild that package. The original package is preserved in the separate game-mod distribution and is identified by its hash in README.md.

To make a new installable distribution after rebuilding the script, use the existing distribution layout and update the compiled script hash in manifest.json. The installer validates that manifest before copying the payload.

Unreal package GUIDs and build metadata may differ between builds. Matching SHA-256 output is not promised. Successful compilation does not validate game behavior or certify the package's safety; reviewers can inspect the source and rebuild independently.
