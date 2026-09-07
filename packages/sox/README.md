# SOX Media Player

SOX Media Player plays local audio and internet radio through a Kindle's Bluetooth or USB audio output. It appears in KUAL and the Kindle Library after installation. Opening its Library item or running `kpm launch sox` starts the local music playlist.

Put local audio in `/mnt/us/music`. The package never owns or removes that directory or any media inside it. Edit `/mnt/us/extensions/sox/menu.json` to customize the internet radio entries; KPM preserves that file during upgrades and after removal.

The player does not support AAC. Files played together must use the same format, sample rate, channel count, and bit depth. Bluetooth must already be paired and connected.

The `kindlehf` and `kindlepw2` artifacts contain the matching hard-float and soft-float binaries from the updated original release distributed through [MobileRead](https://www.mobileread.com/forums/showthread.php?t=368945). The SoX project publishes its [source and licensing terms](https://sourceforge.net/projects/sox/), but the Kindle archive does not identify the corresponding source revisions for its SoX build or bundled codec libraries.
