# Kindle HID Passthrough

This rootfs-free port starts the upstream Bluetooth HID daemon on demand and opens its BT Manager Library application. It can pair and reconnect Bluetooth keyboards, mice, controllers, and remotes while the daemon is running. Launch it again after a reboot. The BT Manager start-on-boot control and its backend action are disabled.

The package preserves `config.ini`, `devices.conf`, and `cache/` in `/mnt/us/kindle_hid_passthrough`. It retains the upstream BT Manager WAF application because its registration uses the writable application database. It stops the exact packaged daemon before upgrades and removal and rejects the operation if that process does not exit within 15 seconds. It does not install the upstream boot service, udev rules, or Button Mapper integration because those write the root filesystem.

The included `uhid.ko` is loaded only when `/dev/uhid` is absent and only after an exact match on kernel release, trailing Lab126 build from `/etc/version.txt`, and Kindle board codename decoded from `/proc/usid`. A firmware without that exact module cannot start the HID daemon. The package currently provides the upstream ARMv7 hard-float release only.
