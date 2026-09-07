# Gambatte-K2

Gambatte-K2 emulates Game Boy and Game Boy Color games on Kindle. It appears in the Kindle Library after installation and can also be launched with `;kpm launch gambatte-k2`.

You must provide your own `.gb` or `.gbc` ROM files. Copy them to a folder on the Kindle, then choose one with the emulator's Open button. ROMs and save files outside the application directory are not removed when the package is upgraded or uninstalled.

The package preserves changes to `config.ini`. The upstream release notes that games can occasionally freeze at startup and touch buttons can become stuck; restarting the emulator clears those conditions.

Source and usage details are available from the [Gambatte-K2 project](https://github.com/crazy-electron/gambatte-k2).
