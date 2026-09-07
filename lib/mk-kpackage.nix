{ lib, pkgs }:
{ id
, name
, author
, description
, version
, platforms
, buildPayload
, src ? null
, dependencies ? [ ]
, buildInputs ? [ ]
, installScript ? null
, uninstallScript ? null
, launchScript ? null
, scriptlet ? null
, passthru ? { }
,
}:
assert builtins.match "[a-z0-9_-]+" id != null;
assert builtins.length version == 3;
assert lib.all (component: builtins.isInt component && component >= 0) version;
assert platforms != [ ];
assert lib.all
  (platform: lib.elem platform [
    "kindle"
    "kindle5"
    "kindlepw2"
    "kindlehf"
  ])
  platforms;
let
  versionString = lib.concatMapStringsSep "." toString version;
  platformString = lib.concatStringsSep "-" platforms;
  filename = "${id}_${versionString}_${platformString}.kpkg";
  manifest = builtins.toJSON {
    manifest_version = 2;
    inherit id name author description version dependencies;
    supported_platforms = platforms;
  };
  copyScript = target: source:
    lib.optionalString (source != null) ''
      cp "${source}" "${target}"
    '';
in
pkgs.runCommand "${id}-${versionString}-${platformString}"
{
  SOURCE = if src == null then "" else src;
  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnutar
    pkgs.gzip
    pkgs.unzip
  ] ++ buildInputs;
  passthru = passthru // {
    kpm = {
      inherit id name author description version platforms dependencies filename manifest;
    };
  } // lib.optionalAttrs (scriptlet != null) { inherit scriptlet; };
}
  ''
    OUTPUT_DIRECTORY=${lib.escapeShellArg (builtins.placeholder "out")}
    PACKAGE_ROOT="$(${lib.getExe' pkgs.coreutils "mktemp"} -d)"
    trap '${lib.getExe' pkgs.coreutils "rm"} -rf "''${PACKAGE_ROOT}"' EXIT
    cd "''${PACKAGE_ROOT}"
    ${buildPayload}
    ${copyScript "install.sh" installScript}
    ${copyScript "uninstall.sh" uninstallScript}
    ${copyScript "launch.sh" launchScript}
    ${lib.getExe' pkgs.coreutils "printf"} '%s' ${lib.escapeShellArg manifest} > manifest.json
    mkdir -p "''${OUTPUT_DIRECTORY}"
    ${lib.getExe pkgs.gnutar} \
      --sort=name \
      --mtime='@1' \
      --owner=0 \
      --group=0 \
      --numeric-owner \
      --format=gnu \
      --null \
      --files-from=<(${lib.getExe pkgs.findutils} . -mindepth 1 -maxdepth 1 -printf '%P\0' | ${lib.getExe' pkgs.coreutils "sort"} -z) \
      -cf - \
      | ${lib.getExe pkgs.gzip} -n > "''${OUTPUT_DIRECTORY}/${filename}"
  ''
