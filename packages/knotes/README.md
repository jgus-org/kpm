# KNotes

KNotes is a [notes and kanban application](https://github.com/crizmo/KNotes) by Kurizu, packaged from its pinned [v1.0-beta.1 release](https://github.com/crizmo/KNotes/releases/tag/v1.0-beta.1).

Notes remain USB-visible in `/mnt/us/documents/KNotes/notes`. The package preserves that directory across upgrades and removal. Its launcher starts the bundled Utild service only when `com.kindlemodding.utild` is unavailable; it leaves an already-running service alone.
