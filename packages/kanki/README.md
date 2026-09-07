# KAnki

KAnki is a [flashcard application](https://github.com/crizmo/KAnki) from Kurizu. This package uses the pinned [v1.1.2 release](https://github.com/crizmo/KAnki/releases/tag/v1.1.2), selecting its legacy archive through firmware 5.12.2.2 as the upstream release notes require.

Use USB storage to replace `/mnt/us/documents/kanki/js/kanki_config.js` and `/mnt/us/documents/kanki/assets/fonts/language.ttf`. The launcher copies those files into KAnki before it starts. The package preserves them because KAnki documents both as user replacements.

KAnki stores flashcard progress at `/Kindle/.active_content_sandbox/kanki/resource/LocalStorage/file__0.localstorage`; package hooks do not modify that path.
