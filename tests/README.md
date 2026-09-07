# Automated tests

The Nix checks cover repository construction and package metadata on every flake host. The following checks run only on the current validated host, `x86_64-linux`:

- `abi` inspects packaged ARM ELF metadata and dependency providers against reproducibly pinned KOReader koxtoolchain 2026.08 runtime libraries. The `kindlehf` and `kindlepw2` trees are a static glibc compatibility reference; their kernel versions are toolchain metadata because QEMU user mode runs on the current host kernel. QEMU cannot execute either fixture's dynamic loader, so that unavailable coverage is recorded as `missing`. The static records identify uncovered `libgomp`/zlib providers and a PW2 `GLIBC_2.15` requirement gap. Declared hard-float operations run with a modern Nix ARM runtime instead; SoX synthesizes a deterministic WAV and verifies its sample count and hash. No generic soft-float runtime is available for the PW2 fixture. The fixtures are online sources, not files exported from a Kindle.
- `kpm-consumer` runs the exact upstream dependency fix commit [`8d870816bc43f2a913df06d083864af4f0c4e1ad`](https://github.com/KindleModding/KPM/commit/8d870816bc43f2a913df06d083864af4f0c4e1ad) in a NixOS VM against a local loopback test repository. That source identifies its library as KPM 0.2.3 and its CLI as 1.0.0, but remains unreleased: the [official repository manifest](https://repo.kindlemodding.org/manifest.v2.json) currently publishes KPM only through 0.2.1. The check derives 46 artifact-platform lifecycle cases from package metadata and, for every case, archives, installs, launches, cleans up, and uninstalls through the real KPM CLI. The 49 launch targets comprise 41 device-boundary handoffs and eight maintenance shell actions. Install and uninstall assertions cover KPM's package store plus declared native, WAF, Scriptlet, and package-specific retained-state behavior, and a missing dependency must produce a clean nonzero rejection. The test preserves upstream core and CLI control flow, supplies an inert FBInk boundary stub, and redirects only the bootstrap repository URL to a loopback empty manifest.

Run all available checks and build the publication tree with:

```sh
nix flake check 'path:.' --option post-build-hook ""
nix build 'path:.#repository' --option post-build-hook ""
```

Run a Linux-only check directly with:

```sh
nix build --out-link result-abi 'path:.#checks.x86_64-linux.abi' --option post-build-hook ""
nix build --out-link result-kpm-consumer 'path:.#checks.x86_64-linux.kpm-consumer' --option post-build-hook ""
nix log 'path:.#checks.x86_64-linux.abi' --option post-build-hook ""
nix log 'path:.#checks.x86_64-linux.kpm-consumer' --option post-build-hook ""
```

An exit status of zero means the requested check has no failed assertion. The ABI report separates fixture, emulation-runtime, inventory, runtime, and functional counts into passed, missing, and failed coverage; successful results are at `result-abi/report.json`, with one artifact record in `result-abi/artifacts/`. A missing static provider or version requirement is unavailable representative-baseline coverage; it is neither a generic-runtime pass nor proof that a physical Kindle fails. A generic-runtime pass also does not establish Kindle glibc compatibility. Failed ABI coverage stops the build and prints the deterministic report through `nix log`. The consumer test exposes `result-kpm-consumer/report.json` and prints the same JSON in its NixOS test log. Its source revision and identity name the unreleased upstream pin. Dynamic `launch_count`, `boundary_handoff_count`, and `actual_application_execution_count` fields classify the 49 evaluated launch targets as 41 boundary handoffs and eight real maintenance shell actions; each case records its launch mode, arguments, boundaries, and execution flag. The `abi` and `kpm-consumer` attributes are absent on hosts other than `x86_64-linux`, where the QEMU runners and fixture setup are validated; those hosts do not run equivalent coverage.

Each launch fixture declares whether it starts the packaged application. Fixtures marked as application execution run the packaged launcher with only explicitly declared device-service boundaries; the assertion observes its terminal effect. Dispatch fixtures instead prove the handoff command, arguments, and working directory. They may replace the final installed application or service only after asserting that the original installed file exists, then restore it before KPM uninstall. kTerm, LIPC, loop, mount, reboot, firewall, and network boundaries use VM-only recorders where required. The real archives and lifecycle hooks are unchanged by those substitutions.

These checks do not run on a Kindle or validate firmware-specific behavior. They do not execute native ARM UI or binary applications in the consumer matrix: a recorded app-manager or kTerm handoff proves only that downstream command boundary. The ABI check's SoX hard-float operation is separate coverage. ABI inspection covers executables extracted from the outer `.kpkg`, not executables inside nested compressed payloads such as a root filesystem image. The checks cannot establish compatibility with every firmware, device model, installed package combination, real-device KPM release, or flake host.
