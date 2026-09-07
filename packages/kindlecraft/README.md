# KindleCraft

KindleCraft packages the bareiron minimalist Minecraft Java Edition 1.21.8 server for hard-float Kindles. Launch it from KPM or `KindleCraft.sh` in the Library, then connect a vanilla client to the Kindle on TCP port 25565.

The server stores its world and player data in `/mnt/us/documents/world.bin`. Upgrades and uninstall leave that file in place, including worlds created by the earlier KindleForge package.

Only `kindlehf` is provided. The pinned upstream executable is a static ARMv5TE binary that uses the hard-float ABI. Upstream does not publish a soft-float executable for `kindlepw2`, and its source tree omits the generated `registries.h` needed to reproduce one directly.

The launch action adds an in-memory firewall rule for TCP port 25565 and then runs the server in the foreground. The rule is not a startup service and does not modify the root filesystem.

Source: [bareiron revision `13370ad3`](https://github.com/gingrspacecadet/bareiron/tree/13370ad3a36cd526270a9bc5a942bdf6ea1869d2), licensed under GPL-3.0.
