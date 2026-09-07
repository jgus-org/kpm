# KindleForge packages for KPM

This repository ports packages from the original [KindleForge package repository](https://github.com/KindleTweaks/Repository) for the current Kindle Package Manager (KPM) catalog.

KWordle installation and its Home screen launcher have been verified on a physical Kindle. Other package and device combinations remain unverified.

## Before you start

You need a compatible jailbroken Kindle with KPM. Start at [KindleModding](https://kindlemodding.org/), then follow its [homebrew installation guide](https://kindlemodding.org/jailbreaking/whats-next/installing-homebrew.html).

## Install a package

Connect the Kindle to Wi-Fi, then open its search bar and enter these commands one at a time:

```
;kpm add-repo https://jgus.github.io/kpm/manifest.v2.json
;kpm update
;kpm install <package>
;kpm launch <package>
```

The first command adds this repository once. Replace `<package>` with the ID of the package you want:

| ID | Package | Description |
| --- | --- | --- |
| `gargoyle` | [Gargoyle](packages/gargoyle/README.md) | Text adventure interpreter |
| `kpomo` | KPomo | Pomodoro focus timer |
| `kreate` | Kreate | Drawing application |
| `kships` | KShips | Battleship |
| `kwordle` | KWordle | Wordle for Kindle |
| `larkplayer` | LARKPlayer | Audiobook reader |
| `toggleads` | Toggle ADs | Toggle Kindle advertisements |
| `updateblockstatus` | UpdateBlock Status | Show OTA update-blocker status |

Installed packages appear in Library with the upstream cover art included by their packages. Toggle ADs, UpdateBlock Status, and Gargoyle also install Home screen launchers.

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
