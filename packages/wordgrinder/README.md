# WordGrinder

WordGrinder 0.9.2 is a terminal word processor. Open it from the Kindle Library; it runs through [kTerm](https://github.com/bfabiszewski/kterm).

Save document sets where you want them on the Kindle USB drive. WordGrinder's startup Lua file and global settings live in `/mnt/us/.wordgrinder`, which KPM does not install, replace, or remove. KPM also leaves any documents that you save inside `/mnt/us/wordgrinder` in place when updating or removing the package.

An external keyboard is recommended. The optional [Kindle HID Passthrough](https://github.com/kbarni/kindle-hid-passthrough) project can provide Bluetooth keyboard support. Consult the bundled `README.wg` for document formats, shortcuts, templates, import, and export.
