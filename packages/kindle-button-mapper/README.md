# Kindle Button Mapper

Open `MapperManager.sh` from the Library to configure input devices and mappings on the Kindle. The manager starts its local helper while the app is open; use its Start and Stop controls for the on-demand mapper daemon. Saving a configuration reloads a running daemon without replacing its virtual input device.

The default configuration explains how to identify a keyboard, gamepad, mouse, or remote and bind events to the included native-reader and KOReader action scripts. Device matching uses its Bluetooth identity or name rather than an unstable `/dev/input/eventX` number.

The package owns only processes whose PID, process start time, executable, and complete arguments match its records. Upgrade and uninstall stop those processes before replacing files and refuse to proceed while an unrecorded instance is using the packaged executable.

Upgrades and uninstall preserve `/mnt/us/kindle-button-mapper/config.ini` and the manager-generated `scripts/auto.sh`. Runtime logs are `daemon.log` and `manager.log` in that directory.

The daemon and manager remain on demand after reboot. This port does not install the upstream root-filesystem boot service or udev rule. It rebuilds the pinned 1.6.0 source as a static ARMv7 hard-float musl executable with a KPM-specific process manager in place of the upstream Upstart calls.

Only `kindlehf` is provided. Upstream 1.6.0 targets the ARMv7 hard-float ABI and does not provide a soft-float `kindlepw2` build.

Source: [kindle-button-mapper-rs v1.6.0](https://github.com/zampierilucas/kindle-button-mapper-rs/tree/fa3a851ef1d26f3045ef27c7dc3465e45d56de14), licensed under GPL-3.0-or-later.
