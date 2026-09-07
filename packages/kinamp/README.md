# KinAMP

Copy audio files to `/mnt/us/music`, then open KinAMP from the Kindle Library. KinAMP stores its settings, radio stations, playlists, and log under `/mnt/us/KinAMP`; KPM preserves those files when updating or removing the package.

The package includes the optional KOReader plugin at `/mnt/us/KinAMP/koreader-plugin`. Copy it to your KOReader `plugins` directory as `kinamp.koplugin` if you use KOReader; KPM does not alter a third-party KOReader installation automatically.

See the [upstream project](https://github.com/kbarni/KinAMP) for supported audio formats, Bluetooth, radio, and KOReader controls.
