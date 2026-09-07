{ lib, pkgs }:
{ artifacts, repository, kpmSource ? null }:
let
  defaultKpmSource = {
    revision = "8d870816bc43f2a913df06d083864af4f0c4e1ad";
    hash = "sha256-WrQ3e7h2GZ2c5Pdd7A6Logp22WcWLtIeFmPsqwnOQNM=";
    packageVersion = "0.2.3";
    runtimeVersion = "0.2.3";
    identity = "upstream-unreleased-fix-8d870816bc43f2a913df06d083864af4f0c4e1ad";
  };
  source = if kpmSource == null then defaultKpmSource else kpmSource;
  sourceRevision = source.revision;
  platforms = [ "kindlehf" "kindlepw2" ];
  contractArtifact = lib.findFirst
    (artifact: artifact.kpm.id == "gambatte-k2" && lib.elem "kindlehf" artifact.kpm.platforms)
    (throw "the consumer contract fixture requires a kindlehf gambatte-k2 artifact")
    artifacts;
  contractUpgradeVersion = [
    1
    0
    1
  ];
  consumerCase = artifact: platform:
    let
      metadata = artifact.consumer.cases;
    in
    assert lib.sort lib.lessThan artifact.kpm.platforms == lib.sort lib.lessThan (builtins.attrNames metadata);
    metadata.${platform} // {
      artifact = artifact.kpm.id;
      archive = "${artifact}/${artifact.kpm.filename}";
      dependencies = artifact.kpm.dependencies;
      inherit platform;
    }
    // lib.optionalAttrs (artifact ? native) { native = artifact.native; }
    // lib.optionalAttrs (artifact ? scriptlet) { scriptlet = artifact.scriptlet; }
    // lib.optionalAttrs (artifact ? waf) { waf = artifact.waf; };
  cases = lib.concatMap
    (artifact:
      assert artifact ? consumer;
      map (platform: consumerCase artifact platform) artifact.kpm.platforms)
    artifacts;
  packageEntry = packageArtifacts: {
    inherit ((builtins.head packageArtifacts).kpm) author description name;
    artifacts = map
      (artifact: {
        dependencies = artifact.kpm.dependencies;
        supported_platforms = artifact.kpm.platforms;
        url = "packages/${artifact.kpm.id}/artifacts/${artifact.kpm.filename}";
        version = artifact.kpm.version;
      })
      packageArtifacts;
  };
  artifactPackages = builtins.listToAttrs (map
    (id: {
      name = id;
      value = packageEntry (lib.filter (artifact: artifact.kpm.id == id) artifacts);
    })
    (lib.unique (map (artifact: artifact.kpm.id) artifacts)));
  ktermVersion = [
    2
    6
    0
  ];
  ktermManifest = builtins.toJSON {
    manifest_version = 2;
    id = "kterm";
    name = "Consumer kTerm fixture";
    author = "KPM consumer test";
    description = "A terminal dispatch recorder for dependent consumer packages";
    version = ktermVersion;
    dependencies = [ ];
    supported_platforms = platforms;
  };
  ktermInstall = pkgs.writeText "consumer-kterm-install.sh" ''
    set -eu
    mkdir -p /mnt/us/extensions/kterm/bin
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "''${*}" >> /var/lib/kpm-consumer/kterm.log' 'exit 0' > /mnt/us/extensions/kterm/bin/kterm
    chmod 755 /mnt/us/extensions/kterm/bin/kterm
  '';
  ktermUninstall = pkgs.writeText "consumer-kterm-uninstall.sh" ''
    set -eu
    rm -rf /mnt/us/extensions/kterm
  '';
  ktermArchive = pkgs.runCommand "consumer-kterm.kpkg"
    {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnutar
        pkgs.gzip
      ];
    } ''
    PACKAGE_DIRECTORY="$(mktemp -d)"
    trap 'rm -rf "''${PACKAGE_DIRECTORY}"' EXIT
    cp ${ktermInstall} "''${PACKAGE_DIRECTORY}/install.sh"
    cp ${ktermUninstall} "''${PACKAGE_DIRECTORY}/uninstall.sh"
    printf '%s' ${lib.escapeShellArg ktermManifest} > "''${PACKAGE_DIRECTORY}/manifest.json"
    mkdir -p "''${out}"
    (
      cd "''${PACKAGE_DIRECTORY}"
      ${lib.getExe pkgs.gnutar} --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner --format=gnu --null --files-from=<(${lib.getExe pkgs.findutils} . -mindepth 1 -maxdepth 1 -printf '%P\0' | ${lib.getExe' pkgs.coreutils "sort"} -z) -cf - | ${lib.getExe pkgs.gzip} -n > "''${out}/kterm_2.6.0_kindlehf-kindlepw2.kpkg"
    )
  '';
  ktermEntry = {
    name = "Consumer kTerm fixture";
    author = "KPM consumer test";
    description = "A terminal dispatch recorder for dependent consumer packages";
    artifacts = [{
      dependencies = [ ];
      supported_platforms = platforms;
      url = "packages/kterm/artifacts/kterm_2.6.0_kindlehf-kindlepw2.kpkg";
      version = ktermVersion;
    }];
  };
  contractEntry = version: url: dependencies: {
    inherit (contractArtifact.kpm) author description name;
    artifacts = [{
      inherit dependencies url version;
      supported_platforms = contractArtifact.kpm.platforms;
    }];
  };
  initialManifest = builtins.toJSON {
    manifest_version = 2;
    id = "kpm-consumer-fixture";
    name = "KPM consumer fixture";
    description = "A local consumer test repository";
    packages = artifactPackages // {
      kterm = ktermEntry;
      missing-dependency = {
        name = "Missing dependency";
        author = "KPM consumer test";
        description = "An unresolved dependency fixture";
        artifacts = [{
          url = "packages/${contractArtifact.kpm.id}/artifacts/${contractArtifact.kpm.filename}";
          version = contractArtifact.kpm.version;
          dependencies = [{
            id = "not-in-index";
            min = [
              1
              0
              0
            ];
          }];
          supported_platforms = [ "kindlehf" ];
        }];
      };
      unsupported-platform = {
        name = "Unsupported platform";
        author = "KPM consumer test";
        description = "A platform-filter fixture";
        artifacts = [{
          url = "packages/${contractArtifact.kpm.id}/artifacts/${contractArtifact.kpm.filename}";
          version = contractArtifact.kpm.version;
          dependencies = [ ];
          supported_platforms = [ "kindlepw2" ];
        }];
      };
    };
  };
  upgradeFilename = "${contractArtifact.kpm.id}_${lib.concatMapStringsSep "." toString contractUpgradeVersion}_${lib.concatStringsSep "-" contractArtifact.kpm.platforms}.kpkg";
  upgradeManifest = builtins.toJSON {
    manifest_version = 2;
    id = "kpm-consumer-fixture";
    name = "KPM consumer fixture";
    description = "A local consumer test repository";
    packages.${contractArtifact.kpm.id} = contractEntry contractUpgradeVersion "packages/${contractArtifact.kpm.id}/artifacts/${upgradeFilename}" [ ];
  };
  bootstrapManifest = builtins.toJSON {
    manifest_version = 2;
    id = "kindlemodding";
    name = "KPM consumer bootstrap";
    description = "A local bootstrap repository";
    packages = { };
  };
  fixture = pkgs.runCommand "kpm-consumer-fixture"
    {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.diffutils
        pkgs.findutils
        pkgs.gnutar
        pkgs.gzip
        pkgs.jq
      ];
    } ''
    ORIGINAL_DIRECTORY="$(mktemp -d)"
    UPGRADE_DIRECTORY="$(mktemp -d)"
    INVALID_DIRECTORY="$(mktemp -d)"
    trap 'rm -rf "''${ORIGINAL_DIRECTORY}" "''${UPGRADE_DIRECTORY}" "''${INVALID_DIRECTORY}"' EXIT
    ${lib.getExe pkgs.gnutar} -xzf ${lib.escapeShellArg "${contractArtifact}/${contractArtifact.kpm.filename}"} -C "''${ORIGINAL_DIRECTORY}"
    cp -a "''${ORIGINAL_DIRECTORY}/." "''${UPGRADE_DIRECTORY}/"
    ${lib.getExe pkgs.jq} --argjson version ${lib.escapeShellArg (builtins.toJSON contractUpgradeVersion)} '.version = $version' "''${UPGRADE_DIRECTORY}/manifest.json" > "''${UPGRADE_DIRECTORY}/manifest.next.json"
    mv "''${UPGRADE_DIRECTORY}/manifest.next.json" "''${UPGRADE_DIRECTORY}/manifest.json"
    ${lib.getExe' pkgs.diffutils "diff"} -r -x manifest.json "''${ORIGINAL_DIRECTORY}" "''${UPGRADE_DIRECTORY}"
    cp -a "''${ORIGINAL_DIRECTORY}/." "''${INVALID_DIRECTORY}/"
    ${lib.getExe pkgs.jq} '.manifest_version = 3' "''${INVALID_DIRECTORY}/manifest.json" > "''${INVALID_DIRECTORY}/manifest.next.json"
    mv "''${INVALID_DIRECTORY}/manifest.next.json" "''${INVALID_DIRECTORY}/manifest.json"
    pack_archive() {
      SOURCE_DIRECTORY="''${1}"
      TARGET_ARCHIVE="''${2}"
      (
        cd "''${SOURCE_DIRECTORY}"
        ${lib.getExe pkgs.findutils} . -mindepth 1 -maxdepth 1 -printf '%P\0' | ${lib.getExe' pkgs.coreutils "sort"} -z | ${lib.getExe pkgs.gnutar} --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner --format=gnu --null --files-from=- -cf - | ${lib.getExe pkgs.gzip} -n > "''${TARGET_ARCHIVE}"
      )
    }
    mkdir -p "''${out}/repository" "''${out}/upgrade-repository/packages/${contractArtifact.kpm.id}/artifacts"
    ${lib.concatMapStrings (artifact: ''
      mkdir -p "''${out}/repository/packages/${artifact.kpm.id}/artifacts"
      cp ${lib.escapeShellArg "${artifact}/${artifact.kpm.filename}"} "''${out}/repository/packages/${artifact.kpm.id}/artifacts/${artifact.kpm.filename}"
    '') artifacts}
    mkdir -p "''${out}/repository/packages/kterm/artifacts"
    cp ${ktermArchive}/kterm_2.6.0_kindlehf-kindlepw2.kpkg "''${out}/repository/packages/kterm/artifacts/"
    pack_archive "''${UPGRADE_DIRECTORY}" "''${out}/upgrade-repository/packages/${contractArtifact.kpm.id}/artifacts/${upgradeFilename}"
    pack_archive "''${INVALID_DIRECTORY}" "''${out}/invalid-manifest.kpkg"
    printf '%s\n' ${lib.escapeShellArg bootstrapManifest} > "''${out}/repository/manifest.v2.json"
    printf '%s\n' ${lib.escapeShellArg initialManifest} > "''${out}/repository/consumer.v2.json"
    printf '%s\n' ${lib.escapeShellArg bootstrapManifest} > "''${out}/upgrade-repository/manifest.v2.json"
    printf '%s\n' ${lib.escapeShellArg upgradeManifest} > "''${out}/upgrade-repository/consumer.v2.json"
  '';
  kpm = platform: pkgs.stdenv.mkDerivation {
    pname = "kpm-consumer-${platform}";
    version = source.packageVersion;
    src = pkgs.fetchFromGitHub {
      owner = "KindleModding";
      repo = "KPM";
      rev = source.revision;
      hash = source.hash;
    };
    nativeBuildInputs = [
      pkgs.meson
      pkgs.ninja
      pkgs.patchelf
      pkgs.pkg-config
    ];
    buildInputs = [
      pkgs.cjson
      pkgs.curl
      pkgs.libarchive
      pkgs.sqlite
    ];
    postPatch = ''
      cp ${./consumer/meson.build} meson.build
      cp ${./consumer/cli-meson.build} cli/meson.build
      cp ${./consumer/fbink.c} stubs/fbink.c
      cp ${./consumer/fbink.h} stubs/fbink.h
      substituteInPlace src/kpm.c --replace-fail "https://repo.kindlemodding.org/manifest.v2.json" "http://127.0.0.1:18080/manifest.v2.json"
    '';
    mesonFlags = [
      "-Ddb_path=/mnt/us/kmc/kpm/kpm.db"
      "-Dkindle_platform=${platform}"
      "-Dpkg_path=/mnt/us/kmc/kpm/packages"
    ];
    installPhase = ''
      install -Dm755 cli/kpm "''${out}/bin/kpm"
      install -Dm755 src/libkpm.so "''${out}/lib/libkpm.so"
      patchelf --set-rpath "''${out}/lib:${lib.makeLibraryPath [ pkgs.cjson pkgs.curl pkgs.libarchive pkgs.sqlite ]}" "''${out}/bin/kpm" "''${out}/lib/libkpm.so"
    '';
    meta.mainProgram = "kpm";
  };
  kpms = builtins.listToAttrs (map (platform: { name = platform; value = kpm platform; }) platforms);
  boundaryFixtures = pkgs.runCommand "kpm-consumer-boundaries" { } ''
    mkdir -p "''${out}/bin"
    for COMMAND_NAME in chroot curl insmod iptables killall losetup mount reboot sleep umount; do
      printf '%s\n' '#!/bin/sh' 'printf "%s %s\\n" "''${0##*/}" "''${*}" >> /var/lib/kpm-consumer/boundary.log' 'exit 0' > "''${out}/bin/''${COMMAND_NAME}"
      chmod 755 "''${out}/bin/''${COMMAND_NAME}"
    done
    printf '%s\n' '#!/bin/sh' 'printf "pgrep %s\\n" "''${*}" >> /var/lib/kpm-consumer/boundary.log' 'exit 1' > "''${out}/bin/pgrep"
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "''${*}" >> /var/lib/kpm-consumer/lipc-set-prop.log' 'exit 0' > "''${out}/bin/lipc-set-prop"
    printf '%s\n' '#!/bin/sh' 'exit 0' > "''${out}/bin/lipc-get-prop"
    chmod 755 "''${out}/bin/pgrep" "''${out}/bin/lipc-set-prop" "''${out}/bin/lipc-get-prop"
  '';
  config = pkgs.writeText "kpm-consumer-config.json" (builtins.toJSON {
    boundary_path = "${boundaryFixtures}/bin";
    http_client = lib.getExe pkgs.curl;
    inherit cases;
    contract = {
      artifact = contractArtifact.kpm.id;
      install_marker = contractArtifact.native.marker;
      invalid_archive = "${fixture}/invalid-manifest.kpkg";
      platform = "kindlehf";
      retained_path = "/mnt/us/extensions/gambatte-k2/config.ini";
      upgrade_repository = "${fixture}/upgrade-repository";
      upgrade_version = lib.concatMapStringsSep "." toString contractUpgradeVersion;
    };
    kpm = builtins.mapAttrs (_: value: "${value}/bin/kpm") kpms;
    repository = "${fixture}/repository";
    repository_url = "http://127.0.0.1:18080/consumer.v2.json";
    runtime_version = source.runtimeVersion;
    source_identity = source.identity;
    source_revision = source.revision;
  });
  consumerTest = pkgs.writeText "kpm-consumer-test.py" (builtins.readFile ./consumer/test.py);
in
assert lib.all (name: builtins.hasAttr name source) [ "revision" "hash" "packageVersion" "runtimeVersion" "identity" ];
pkgs.testers.nixosTest {
  name = "kpm-consumer";
  nodes.machine = { ... }: {
    environment.systemPackages = [ pkgs.curl pkgs.gnutar pkgs.jq pkgs.python3 pkgs.sqlite ] ++ builtins.attrValues kpms;
    virtualisation.diskSize = 8192;
    virtualisation.memorySize = 2048;
  };
  testScript = ''
    import runpy

    start_all()
    runner = runpy.run_path(${builtins.toJSON (toString consumerTest)})
    runner["run"](machine, ${builtins.toJSON (toString config)})
  '';
}
