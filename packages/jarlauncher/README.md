# JarLauncher

JarLauncher runs a Java archive in kTerm. Copy your archive to `/mnt/us/extensions/JarLauncher/jar.jar`, then open JarLauncher from the Kindle Library or run `;kpm launch jarlauncher`.

The package includes the matching Azul Zulu Java 8 runtime for hard-float and soft-float Kindles. KPM selects the correct artifact and installs kTerm 2.6 or newer as a dependency. Java is package-owned and is replaced on upgrade and removed on final uninstall; no separate Java downloader runs on the Kindle.

Edit `/mnt/us/extensions/JarLauncher/bin/config.sh` over USB or SSH to change the archive path, Java arguments, or archive arguments. The configuration and `jar.jar` survive upgrades. User-created files produced by the Java application are retained on upgrade and are not recursively deleted on uninstall.

This port follows the workflow documented by [JarLauncher 0.1.2](https://github.com/ThatPotatoDev/JarLauncher/releases/tag/v0.1.2), with a new launcher and configuration written for KPM. It redistributes no files from the unlicensed upstream release. The bundled Azul Zulu runtime carries its vendor and OpenJDK license files in `Java/`.
