# Alpine Linux

This package installs the upstream [Alpine Linux for Kindle v0.2-alpha2](https://github.com/schuhumi/alpine_kindle/releases/tag/v0.2-alpha2) ARMv7 hard-float image. Upstream tested it on the Paperwhite 3. It requires a touchscreen, at least 512 MiB of RAM, and about 3 GiB of free userstore space for installation and the first launch. Installation leaves the Kindle root filesystem unchanged.

Open **Alpine Linux** from the Library to start its MATE desktop, or **Alpine Linux Shell** to open its chroot shell in kTerm. The desktop runs alongside the Kindle interface, so it does not get the RAM savings of upstream's optional Upstart service. Exit the desktop or shell normally so the package can unmount the image.

Do not expose USB mass storage while Alpine is running. The disk image is on the same userstore partition, and concurrent Kindle and computer writes can corrupt it. USBNetwork does not expose that partition as mass storage.

The first launch checks the packaged upstream ZIP and creates `/mnt/us/alpine.ext3` through a temporary sibling. An existing file or link at that path is left untouched. The image uses upstream's default `alpine` user and password. It contains a 2019 Alpine edge snapshot and should be treated as an old, unsupported environment.

Exit Alpine before upgrading or removing the package. Both lifecycle hooks reject an active mount or loop attachment without changing the image or managed tools. Current KPM releases can continue an upgrade after the old uninstall hook reports failure, so an attempted active upgrade may remove KPM's package record and require a reinstall after Alpine exits. The package never owns `/mnt/us/alpine.ext3` or `/mnt/us/alpine.log`; those files and everything stored inside the image remain in place.
