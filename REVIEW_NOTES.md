# Review notes

## Included game code

PistolGame: mod game class, NPC health tracking and death handling.
PistolPlayerController: pistol input, ammunition, shot traces, reload timing, flashlight and draw/holster state.
PistolViewModel: M9 mesh/audio loads and weapon/light animation.
PistolHUD: NPC health bars, pickup prompt and ammunition pickup confirmation.
M9WorldReplacements: runtime camera/battery visual replacement and magazine pickup selection.
M9WorldProp: visual proxy tracking the original world object.
M9MaterialLibrary: materials instantiated from existing Outlast material assets.
M9Corpse: NPC corpse physics or simplified collapse.

These files compile to an UnrealScript package. The distribution does not provide a custom native DLL or game EXE. UnrealScript calls the game's existing native engine functions.

## Installer: INSTALL.cmd and Install.ps1

INSTALL.cmd invokes Windows PowerShell with process-local -ExecutionPolicy Bypass to run the supplied readable Install.ps1. It does not change the system execution policy.

Install.ps1 checks that Outlast is closed, validates the selected game folder, validates payload hashes and target path containment, backs up existing destination files, moves three recognized legacy mod duplicates into that backup, copies the manifest-listed payload and verifies the resulting hashes. It does not intentionally edit save files. It does not launch the game automatically.

The full expected payload list is in DistributionScripts/manifest.json. The installer sources need that manifest plus the Files directory from the separate installable distribution to run.

## Launcher: START_M9.cmd and Level_Launcher.bat

START_M9.cmd changes to its own directory and calls Level_Launcher.bat OutlastPistolMod.

Level_Launcher.bat is based on superboo07's Level Launcher v17. It creates a directory junction for mod content and uses robocopy to back up and temporarily replace game configuration. It starts the installed OLGame.exe with -NoSteam -NOHOMEDIR -log and, after the process exits normally, restores configuration and removes the content junction. It should be inspected as supplied, including its other command handlers.

The launcher contains optional network download/update commands, including curl calls to Dropbox and an update handler that can download and run a replacement launcher. Shipped Settings.ini sets DisplayChangelog=false, CheckForUpdates=false, and UpdateAutomatically=false. That disables the normal automatic checks; it does not remove the optional download/update code from the batch file. If Settings.ini is missing, the launcher can attempt a download. No claim is made that the launcher has no network-capable code.

Launcher project/guide: https://github.com/superboo07/Outlast-Level-Editor
https://steamcommunity.com/sharedfiles/filedetails/?id=2477722721

## Asset package and provenance

M9Assets.OLContent was supplied in an existing working mod archive and retained byte-for-byte. This review archive contains the custom script source, not the editable source project for its model/audio assets. Their authorship and redistribution permissions have not been established here. The game material references resolve to the user's installed Outlast resources; those material resources are not included in this source archive.

## Verification scope

The recorded r4 compilation completed with zero errors and zero warnings. The compiled package was also read by an independent decompiler during development. Neither step is a malware scan. r4 has not been confirmed by a complete in-game playthrough; magazine pickup reliability remains under testing.

The exact reason for Nexus quarantine has not been disclosed. This package is provided for manual review without changing filenames or repackaging files to evade scanning.
