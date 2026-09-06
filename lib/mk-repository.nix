{ lib, pkgs }:
{ artifacts
, id ? "kindleforge-conversions"
, name ? "KindleForge Conversions"
, description ? "KindleForge packages converted for KPM"
,
}:
let
  groupedArtifacts = lib.groupBy (artifact: artifact.kpm.id) artifacts;
  packageEntry = packageArtifacts:
    let
      first = builtins.head packageArtifacts;
      sameMetadata = artifact:
        artifact.kpm.name == first.kpm.name
        && artifact.kpm.author == first.kpm.author
        && artifact.kpm.description == first.kpm.description;
    in
    assert lib.all sameMetadata packageArtifacts;
    {
      inherit (first.kpm) name author description;
      artifacts = map
        (artifact: {
          url = "packages/${artifact.kpm.id}/artifacts/${artifact.kpm.filename}";
          inherit (artifact.kpm) version dependencies;
          supported_platforms = artifact.kpm.platforms;
        })
        packageArtifacts;
    };
  manifest = builtins.toJSON {
    manifest_version = 2;
    inherit id name description;
    packages = lib.mapAttrs (_: packageEntry) groupedArtifacts;
  };
  copyArtifact = artifact: ''
    mkdir -p "''${OUTPUT_DIRECTORY}/packages/${artifact.kpm.id}/artifacts"
    cp "${artifact}/${artifact.kpm.filename}" "''${OUTPUT_DIRECTORY}/packages/${artifact.kpm.id}/artifacts/"
  '';
in
pkgs.runCommand "${id}-repository" { nativeBuildInputs = [ pkgs.coreutils ]; } ''
  OUTPUT_DIRECTORY=${lib.escapeShellArg (builtins.placeholder "out")}
  mkdir -p "''${OUTPUT_DIRECTORY}"
  ${lib.concatMapStrings copyArtifact artifacts}
  ${lib.getExe' pkgs.coreutils "printf"} '%s\n' ${lib.escapeShellArg manifest} > "''${OUTPUT_DIRECTORY}/manifest.v2.json"
''
