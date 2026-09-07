---
name: create-kpm-package
description: Create or convert reproducible packages for the current Kindle Package Manager (KPM), including payload selection, lifecycle hooks, Library Scriptlets, ABI variants, validation, and static repository publication. Use for KPM ports or new KPM packages; do not use this as a legacy KindleForge packaging guide.
---

Build a KPM package from the current KPM consumer contract, then make its runtime integration explicit. Treat an upstream Forge package as source material, not as proof that its installer, layout, or launcher remains appropriate.

## Establish the target and source

Identify the released KPM version and supported device platforms before selecting payloads. KPM 0.2.1 and 0.2.2 have been verified with package and repository manifest schema v2, but verify the target release and its source or documentation whenever compatibility matters; do not infer a permanent schema rule from that observation. Read the current KPM package documentation and source alongside the upstream package archive:

- [KPM package documentation](https://kindlemodding.org/kindle-dev/kpm/creating-a-package.html)
- [KPM source](https://github.com/KindleModding/KPM)
- [SH Integration documentation](https://kindlemodding.org/kindle-dev/scriptlets.html)
- [SH Integration source](https://github.com/KindleModding/sh_integration)

Inspect the chosen archive, launchers, configuration, bundled libraries, and user-facing instructions without executing an upstream installer. Pin the selected download and its content hash. A package definition must state which upstream version and ABI artifact it ships; a filename that lists several devices does not establish which ABI a running device uses.

For firmware-dependent variants, read the version from an authoritative device source, normalize all version components, and compare them deliberately. Preserve upstream variant selection when the KPM platform label alone cannot prove the required firmware baseline.

## Form the artifact for the consumer

A KPM archive is a gzip-compressed tar with bare members at its root: `manifest.json`, payload directories, and optional `install.sh`, `uninstall.sh`, and `launch.sh`. Do not add an enclosing package directory or prefix members with `./`: the tested 0.2.1 consumer rejects `./manifest.json` even though it is a valid tar member. Use deterministic member ordering, tar metadata, and gzip timestamps for reproducibility. The package manifest describes one artifact, including its version, dependencies, and supported platforms; the repository manifest serializes package metadata and relative artifact URLs. Keep those two schemas separate from a build system's helper arguments.

The KPM hook and launch contract is runtime-sensitive:

- KPM invokes hooks with `sh` from the extracted package directory. Resolve packaged payload paths against that directory; use explicit on-device paths for deployment and system integration.
- A package intended for `kpm launch <id>` needs a root `launch.sh`. Keep the application launch behavior there so every entry point has one source of truth.
- Pass through launch arguments and preserve the working directory expected by the upstream wrapper or binary.
- Generate hooks and launch scripts as normal package files. Do not allow host build-store paths into the archive.

The [jgus/kpm reference implementation](https://github.com/jgus/kpm) uses `lib/mk-kpackage.nix`, `lib/mk-repository.nix`, and `lib/check-repository.nix` for these rules. Their Nix interface and directory names are repository-specific, not a KPM protocol requirement.

## Choose the runtime integration and ownership policy

Use a WAF/Mesquite integration only when the upstream application actually requires its registration, Mesquite deployment, and LIPC behavior. A native extension or binary package often needs a different deployment and launch arrangement. Factor repeated, proven lifecycle mechanics into a shared helper; keep payload paths, registration identifiers, launch commands, firmware gates, and retained state package-specific.

Do not modify the root filesystem from hooks; current KPM documentation treats that as unsupported. Define ownership before writing an install hook. A fresh install must reject an existing foreign deployment or Scriptlet without changing it. Only recognize a prior retained deployment when it has the exact marker and residual shape the package owns; never adopt an arbitrary directory because its name matches.

Model the actual upgrade sequence: the old package receives `uninstall.sh upgrade`, its package directory is removed, and the new package receives `install.sh upgrade`. The old hook must remove only the exact old launcher that would block replacement while retaining the state and provenance needed by the new hook. A failed new install can cause its normal uninstall hook to run, so rollback must leave the prior retained state intact. For payloads mixed with configuration or saves, stage and swap package-owned files atomically, or restore a precise backup. Final uninstall removes exact shipped files while preserving only user state that the package documents and can safely recognize on reinstall.

Test this policy with real filesystem fixtures: fresh install, old-uninstall/new-install upgrade, failed staged install, final uninstall, repeat uninstall, and foreign collisions. Snapshot foreign trees before both the failed install and its cleanup callback. When application registration uses SQLite, test with a real fixture database and preserve unrelated rows.

## Add a Library item deliberately

A native launcher, KUAL registration, or installed extension does not automatically create a Kindle Library item. Install a Documents Scriptlet when the package should appear in Library. It should call the KPM binary at `/var/local/kmc/bin/kpm launch <id>`, which then invokes the package's `launch.sh`.

SH Integration reads Scriptlet metadata only from the first six lines. Put optional `# Name:`, `# Author:`, and `# Icon:` metadata there. Use `# DontUseFBInk` when the graphical application should control its presentation, then invoke KPM. Treat the Scriptlet as an owned file: compare it before replacing or removing it, and remove the old owned Scriptlet during upgrade before the new one is installed.

Use authentic upstream cover art unchanged where available. For a small image, an inline `data:image/...;base64,...` header can be appropriate. For a large image already installed at a path that passes SH Integration's `R_OK|W_OK` access check before scanner processing, prefer a filesystem `# Icon: /mnt/us/...` reference: the current SH Integration base64 extraction loop repeatedly measures the header and can become impractically slow for multi-megabyte inline covers. Verify the referenced image is present before the Documents Scriptlet is copied. Gargoyle is one native-package example of this choice; it is not a universal layout rule.

## Validate the real deliverable

Build the actual artifact, inspect its compressed members, and exercise hooks against redirected temporary roots. Nix projects should use quoted flake references and disable post-build hooks for local builds, for example:

```sh
nix flake check --option post-build-hook "" 'path:.'
```

Check the emitted archive rather than only evaluating its package expression: bare member names, manifest JSON, no host-store paths in runtime files, shell syntax, Scriptlet first-six-line metadata, icon format and bytes, and the Scriptlet-to-`kpm launch` path. Test every ABI artifact that can differ in payload, icon availability, runtime command, or firmware selection.

Publish the generated static repository shape together: for the tested KPM 0.2.x contract, a v2 repository manifest and each artifact at the relative URL recorded in that manifest. Validate it as a released KPM consumer would fetch it, not only from a local derivation. Give `kpm add-repo` the full manifest URL, such as `https://<owner>.github.io/<repo>/manifest.v2.json`, rather than the repository base URL; verify that input contract against the target release. The jgus/kpm reference layout is `manifest.v2.json` plus `packages/<id>/artifacts/<artifact>.kpkg`.

Put substantial user setup in `packages/<id>/README.md` and link to it from the repository package list. Keep it concise, explain required valid inputs or data locations, and link to authoritative upstream documentation. For example, an interpreter package needs real compatible story files; a program distribution is not evidence that it ships games.

When a native UI appears to exit, distinguish stderr warnings from the true child-process status. Inspect the wrapper: a cleanup command after the binary can mask its exit code. Reproduce with a known-valid minimal input that exercises the interpreter or renderer, then capture the child status before cleanup.

For native payloads, inspect `LD_LIBRARY_PATH` shadowing and the ELF version requirements of both the application and its system dependencies. Verify that a target firmware's system library satisfies the application before removing a bundled copy; do not treat library removal as a generic fix. Gargoyle is a scoped example: a bundled `libm` built for an older GLIBC conflicted with a newer firmware dependency chain, and the port maintainer recommended omitting it in [the upstream port discussion](https://www.mobileread.com/forums/showthread.php?p=4508221). That compatibility finding is separate from GTK warning output or a Library-indexing symptom.
