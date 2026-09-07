---
name: create-kpm-package
description: Create or convert reproducible packages for the current Kindle Package Manager (KPM), including payload selection, lifecycle hooks, Library Scriptlets, ABI variants, validation, and static repository publication. Use for KPM ports or new KPM packages; do not use this as a legacy KindleForge packaging guide.
---

Build a KPM package from the current consumer contract and make its runtime integration explicit. Treat an upstream Forge package as source material, not as proof that its installer, layout, launcher, ownership, or platform declaration remains appropriate.

## Establish the target and source

Identify the target KPM release and supported platforms before selecting payloads. Read the target package consumer and documentation alongside the upstream archive, launcher, configuration, bundled libraries, Scriptlets, cover art, licenses, and user instructions without executing an upstream installer:

- [KPM package documentation](https://kindlemodding.org/kindle-dev/kpm/creating-a-package.html)
- [KPM source](https://github.com/KindleModding/KPM)
- [SH Integration documentation](https://kindlemodding.org/kindle-dev/scriptlets.html)
- [SH Integration source](https://github.com/KindleModding/sh_integration)

Pin the source download with its API or release metadata, SHA-256, ABI, and license or redistribution status. A Forge filename or platform label does not establish the ABI a device uses: inspect ELF interpreters, ARM attributes, `DT_NEEDED`, and firmware requirements for every declared artifact. Normalize firmware components before comparison and retain upstream variant selection when the KPM label cannot prove the required baseline. Do not describe a package as device-verified unless it was actually tested on that device.

## Form the artifact for the consumer

A KPM archive is a compressed tar with bare members at its root: `manifest.json`, payload directories, and optional `install.sh`, `uninstall.sh`, and `launch.sh`. The tested 0.2.x consumers reject `./manifest.json`; verify the target release rather than generalizing this to every consumer. libarchive filters determine accepted compression, so gzip and xz can be valid inputs; deterministic gzip is a repository producer convention. Use deterministic ordering, metadata, and timestamps. Keep package and repository manifest schemas separate from build helper arguments, and choose explicit runtime payload roots rather than reproducing an upstream extraction into `/mnt/us`.

KPM runs hooks with `sh` from the extracted package directory. Resolve packaged files relative to that directory, use explicit on-device paths for deployment, and keep one root `launch.sh` for `kpm launch <id>`, passing through arguments and preserving the required working directory. Generate hooks and launchers as package files and exclude host build-store paths.

The [jgus/kpm reference implementation](https://github.com/jgus/kpm) uses `lib/mk-kpackage.nix`, `lib/mk-repository.nix`, and `lib/check-repository.nix`; those interfaces are repository conventions, not KPM protocol requirements.

## Choose integration, ownership, and upgrade behavior

Use Mesquite/WAF registration and LIPC only when the application requires them. Factor only repeated, proven lifecycle mechanics into shared helpers; keep payload paths, registration identifiers, commands, firmware gates, and retained state package-specific. Lifecycle hooks must not write or remount rootfs. An explicitly launched maintenance tool may perform its documented action when installation is side-effect free and the package documents the boundary. A package does not own a separate component merely because it installs or invokes it; removal must leave independently installed components and registrations intact. State omitted boot, udev, or rootfs integration in rootless package descriptions.

Define ownership before mutation. Reject foreign deployment roots, markers, Scriptlets, retained paths, and dangling symlinks without changing them. Accept a retained deployment only with its exact marker and residual shape. Treat every external Scriptlet as an owned file: compare before replacing or removing it and remove only an exact owned copy. Static Scriptlets are compatible with this policy; self-mutating metadata is not.

Model the old `uninstall.sh upgrade`, extracted-package removal, and new `install.sh` sequence. The old hook removes only the exact old launcher that blocks replacement and leaves retained state and its ownership marker. The inspected KPM main revision `ffa767fffadd731bd59f2bca8c83231f4fc0ab2d` (0.3.0 headers) and final 0.2.2 revision `799adf431223d2cfa782a6a4ad07d809f120100b` warn when old uninstall fails and continue into new installation; main 0.3 also invokes a no-argument uninstall after a failed install. Treat these as KPM bugs: package workarounds are justified only for critical data safety, and should identify the upstream fix. Packages must not require the undocumented new-install `upgrade` argument merely because main passes it. Normal uninstall should stop and wait for runtime resources belonging to this package, while install should perform read-only checks and assert that no package-owned image or process is active before mutating anything. Do not teach package hooks to restore KPM records or perform active recovery.

Only as a proposed critical data-safety exception for the inspected 0.3 development cleanup path, a helper may use attempt-local success provenance to ensure a no-argument uninstall after a failed install cannot consume a prior retained deployment. This is not a general KPM contract or a requirement for released 0.2.2. Complete read-only preflight, atomically reserve `.kpm-install-success.pending` in the extracted package directory before target mutation, and rename it to `.kpm-install-success` only after all package trees and owned Scriptlets are committed. Cleanup may remove only attempt-local pending state and must return when the success marker is absent. This exception is temporary: remove it when KPM provides an explicit safe failed-install cleanup contract or the supported KPM floor excludes the unsafe consumer. Do not create a failure sentinel only from an exit trap: the extracted package store may be full, and that write can mask the original failure. Identify the upstream fix: KPM should abort upgrade when old uninstall fails and distinguish failed-attempt cleanup from final uninstall, preserving the old tree/config while limiting fresh partial cleanup to the new attempt.

For `lib/mk-native-package.nix`, create a predictable transaction directory atomically after preflight; an existing directory is a failure and must remain untouched. Register cleanup only after this invocation created it. Stage the complete replacement and all owned Scriptlets, copy declared preserved paths over staged defaults only after removing the staged path, merge unmanaged files safely, then move old trees and overwritten Scriptlets to backups and install the staged content. Keep rollback active through a coordinated Mesquite and Documents swap, and garbage-collect backups only after commit and success provenance. Final uninstall removes an exact shipped file and symlink inventory, excludes preserved paths and descendants, removes empty directories in reverse order, and never recursively removes a tree containing unknown data. Handle obsolete files and file/directory transitions.

Guard inventory removal against symlink parents. In POSIX shell, function variables are global: isolate recursive merge calls in subshells or restore every variable. Test empty directories, dotfiles, names beginning with two dots, multiple siblings, copy failures, foreign collisions, dangling links, repeat uninstall, and real SQLite fixtures that preserve unrelated rows. When adapting a simple Scriptlet installer, early-return on an exact-owned regular file before staging or gate the path with provenance; uninstall inventory must not remove a symlink merely because its dereferenced bytes match the shipped file.

## Handle runtime resources and services

Kindle userstore VFAT does not support symlinks, hard links, or FIFOs. Materialize vendor runtime links during the build and assert that emitted archives contain no link entries. Put runtime FIFOs and temporary hard-link PID claims on `/tmp`, never the userstore; the current mapper names are `/tmp/kpm-kindle-button-mapper-{daemon,helper}.pid`.

A package-owned service record must contain PID, `/proc` start time, actual executable, and complete arguments. Install signal handlers before publishing an atomic PID claim as ready. Detect stale or malformed `/proc` state, exec'ed loaders, and the kernel ` (deleted)` executable suffix; scan the exact executable even if its installed path is no longer executable, revalidate identity immediately before signaling, and use a bounded stop. Test stale, foreign, stuck, concurrent, and replacement processes. WAF shutdown must stop the Mesquite UI as well as a background helper. Start a bundled LIPC daemon only when absent, probe bounded readiness after a daemon that forks before registering its publisher, and never stop a possibly shared instance.

Source UI registration in application databases can remain rootfs-free. Disable unsupported frontend and backend autostart explicitly rather than dropping only the UI or documenting the mismatch. If a useful WAF manager is released with an Upstart-hardcoded helper, inspect and rebuild it before omitting the manager. A static musl helper is safe only after checking actual dependencies for `dlopen` or shared-library FFI; the inspected Button Mapper binary delegates LIPC to external tools and has no such dependency. A rootfs-free HID launcher may skip module selection when `/dev/uhid` exists; otherwise derive and require the exact module filename from kernel release, Lab126 build, and serial-decoded board codename.

## Add Library entries deliberately

A launcher, KUAL registration, or extension does not create a Library item. Install a Documents Scriptlet when needed; it should invoke `/var/local/kmc/bin/kpm launch <id>`. SH Integration reads metadata only from the first six lines, so put `# Name:`, `# Author:`, `# Icon:`, and optional `# DontUseFBInk` there, then verify path, ownership, and dispatch arguments in fixtures.

Use authentic upstream art unchanged where available and audit that art in manager packages as well as applications. For a large cover, decode it at build time and install it at a path that passes SH Integration's `R_OK|W_OK` check, using a filesystem icon reference instead of a costly inline header; verify the bytes, format, dimensions, and presence before copying the Scriptlet. Multiple entries may share one launcher while retaining entry-specific paths and metadata.

## Preserve application state and special packages

Treat configuration, playlists, cookies, sync collections, media, saves, notes, progress databases, and user JARs as state when the application owns or documents them. Keep it outside the deployment root where possible, or retain only declared paths and merge unknown unmanaged data according to the ownership policy. A bundled integration for another application belongs under a package-managed path for documented manual copying only when the target path and ownership are stable. Remove vendor self-update scripts that fetch and execute mutable remote installers.

For Alpine Linux, keep the user-owned mutable 2 GiB image outside the managed tooltree, ship a pinned compressed source, and initialize the image only on first explicit launch through a checked temporary sibling and atomic rename. This avoids repeated upgrade copies exceeding 4 GiB. Validate extraction status and expected uncompressed size; do not add a second full decompression test when the extraction command already reports member CRC failures. Mount fixtures must fail each acquisition independently, clean D-Bus, sysfs, procfs, devpts, `/dev`, image root, and loop attachment in reverse order, preserve runtime failure status, and return cleanup failure only after a successful action.

For maintenance packages, put payloads under a package-specific userstore directory and gate firmware and prerequisites immediately before explicit launch. Constrain dynamic release metadata and asset URLs to expected upstream identifiers, preserve the source parser's format checks, pin each release and redistributed license, and do not claim independent legal or signature verification. If launch temporarily remounts a filesystem, restore read-only state through cleanup while retaining the underlying status. For JVM packages, pin one JVM per ABI and preserve user JARs/config separately; materialize all vendor links before archiving because VFAT cannot extract them.

## Validate and publish

Build and inspect every actual artifact. Exercise hooks with redirected roots and verify shell syntax, JSON, bare members, no host-store paths, Scriptlet first-six-line metadata, icon bytes/format, and the Scriptlet-to-launch path. Inspect native `LD_LIBRARY_PATH`, ELF requirements, and target-firmware libraries before removing bundled libraries. When a UI appears to exit, capture the child status before cleanup and reproduce with a valid minimal input; stderr warnings are not the process result.

Expose generic lifecycle metadata through artifact passthru so repository checks cover every artifact without package-ID branches; builder-owned KPM and Scriptlet metadata must override caller passthru keys. Generic `passthru.tests` should invoke package-specific meaningful runtime and recovery fixtures, including host builds where target-architecture controllers cannot run. Test every ABI variant, including differing payloads, icons, commands, and firmware selection.

Use quoted flake references and disable post-build hooks for local Nix checks:

```sh
nix flake check --option post-build-hook "" 'path:.'
```

Publish a static repository manifest and every artifact at its recorded relative URL. Validate it as the target consumer would fetch it. For the tested 0.2.x contract, use a v2 manifest and give `kpm add-repo` the full manifest URL, such as `https://owner.github.io/repo/manifest.v2.json`; the `jgus/kpm` layout is `manifest.v2.json` plus `packages/<id>/artifacts/<artifact>.kpkg`. Put concise setup and valid input/data requirements in `packages/<id>/README.md`, linked from the package list; a program distribution does not prove that compatible content ships with it. Check dependencies against the current schema, including kTerm's `min` field.
