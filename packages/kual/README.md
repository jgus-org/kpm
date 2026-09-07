# PEKI KUAL Installer

This package contains PEKI 1.0, an installer and launcher for the Kindle Unified Application Launcher. Open “PEKI KUAL Installer” or run `;kpm launch kual` to perform PEKI's explicit action. If KUAL is absent, PEKI copies its bundled booklet into the Kindle system and registers it. If a KUAL booklet already exists, PEKI leaves that file untouched and launches it.

Installation through KPM only places PEKI's files and its Library launcher under `/mnt/us/documents`; it does not install, replace, remove, or launch KUAL. PEKI itself requires firmware 5.12.2.2 or newer and Universal Hotfix 2.3.7 MAX.

Removing this package removes only the PEKI source booklet, license, and Library launcher. Any KUAL booklet installed by PEKI is a separate system integration and remains installed.

Source and operating details are available from the [PEKI project](https://github.com/KindleTweaks/PEKI). The packaged files are licensed under CC BY-NC-SA 4.0.
