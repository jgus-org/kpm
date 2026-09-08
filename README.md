# KindleForge packages for KPM

This repository ports packages from the original [KindleForge package repository](https://github.com/KindleTweaks/Repository) for the current Kindle Package Manager (KPM) catalog.

Not all packages have been tested. If you encounter errors you believe are related to packaging, please file an issue, or better yet propose a PR. Thanks!

## Before you start

You need a compatible jailbroken Kindle with KPM. Start at [KindleModding](https://kindlemodding.org/), then follow its [homebrew installation guide](https://kindlemodding.org/jailbreaking/whats-next/installing-homebrew.html).

## Install a package

Connect the Kindle to Wi-Fi, then open its search bar and enter these commands one at a time:

```
;kpm add-repo https://jgus-org.github.io/kpm/manifest.v2.json
;kpm update
;kpm install <package>
;kpm launch <package>
```

The first command adds this repository once. Replace `<package>` with the ID of the package you want:

| ID | Package | Description |
| --- | --- | --- |
| `alpinelinux` | [Alpine Linux](packages/alpinelinux/README.md) | Alpine Linux chroot and MATE desktop |
| `gambatte-k2` | [Gambatte-K2](packages/gambatte-k2/README.md) | Game Boy and Game Boy Color emulator |
| `gargoyle` | [Gargoyle](packages/gargoyle/README.md) | Text adventure interpreter |
| `gnomegames` | [Gnome Games Suite](packages/gnomegames/README.md) | Chess and Mines games |
| `hotfixupdater` | [HotfixUpdater](packages/hotfixupdater/README.md) | Update an installed Universal Hotfix |
| `jarlauncher` | [JarLauncher](packages/jarlauncher/README.md) | Run a user-provided Java archive |
| `kanki` | [KAnki](packages/kanki/README.md) | Flashcard app |
| `kinamp` | [KinAMP](packages/kinamp/README.md) | Music player |
| `kindle-button-mapper` | [Kindle Button Mapper](packages/kindle-button-mapper/README.md) | Map Kindle buttons and Bluetooth controllers |
| `kindle-hid-passthrough` | [Kindle HID Passthrough](packages/kindle-hid-passthrough/README.md) | On-demand Bluetooth HID host and manager |
| `kindlecraft` | [KindleCraft](packages/kindlecraft/README.md) | Minimal Minecraft Java Edition server |
| `kindlefetch` | [KindleFetch](packages/kindlefetch/README.md) | Book downloader for kTerm |
| `knotes` | [KNotes](packages/knotes/README.md) | Notes and kanban app |
| `kpomo` | KPomo | Pomodoro focus timer |
| `kreate` | Kreate | Drawing application |
| `kships` | KShips | Battleship |
| `kual` | [PEKI KUAL Installer](packages/kual/README.md) | Install or launch KUAL through PEKI |
| `kwordle` | KWordle | Wordle for Kindle |
| `larkplayer` | LARKPlayer | Audiobook reader |
| `ranki` | [RAnki](packages/ranki/README.md) | Anki flashcard client |
| `sox` | [SOX Media Player](packages/sox/README.md) | Bluetooth and USB audio player |
| `textadept` | [Textadept](packages/textadept/README.md) | Programmable text editor |
| `toggleads` | Toggle ADs | Toggle Kindle advertisements |
| `updateblockstatus` | UpdateBlock Status | Show OTA update-blocker status |
| `wordgrinder` | [WordGrinder](packages/wordgrinder/README.md) | Distraction-free word processor |

Packages install Library launchers and upstream cover art where available.

Developers can find the automated-test scope and commands in [tests/README.md](tests/README.md).

## Everyday use

Use the Kindle search bar for KPM commands. Replace `kwordle` with a package ID from the table above when appropriate.

| Action | Command |
| --- | --- |
| Find a package | `;kpm search wordle` |
| Refresh package information | `;kpm update` |
| Update installed packages | `;kpm upgrade` |
| Launch an installed package | `;kpm launch kwordle` |
| View configured repositories | `;kpm list-repo` |
| Optionally remove an installed package | `;kpm uninstall kwordle` |

`update` refreshes package information, while `upgrade` updates installed packages. `launch` works for packages that provide a launch action; installed applications may also add their own way to start them.
