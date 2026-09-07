# HotfixUpdater

HotfixUpdater 1.0.2 checks the official KindleModding Hotfix releases and applies a newer Universal Hotfix when you explicitly open its Library item or run `;kpm launch hotfixupdater`. Installing or upgrading this package does not run the updater or modify the Kindle root filesystem.

It requires firmware 5.12.2.2 or newer and an already installed Universal Hotfix. The updater obtains release metadata from `api.github.com/repos/KindleModding/Hotfix`, accepts only the named `Update_hotfix_universal.bin` asset under the corresponding GitHub releases path, and uses its bundled KindleTool to parse the signed Kindle update before running its payload.

Removing the package removes only the packaged updater, KindleTool programs, license, and Library launcher. It does not remove or roll back the Universal Hotfix.

Source and operating details are available from the [HotfixUpdater project](https://github.com/KindleTweaks/HotfixUpdater). HotfixUpdater is licensed under CC BY-NC-SA 4.0; the bundled KindleTool programs are GPL-3.0.
