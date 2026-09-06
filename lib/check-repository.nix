{ lib, pkgs }:
{ artifacts, repository }:
let
  wafDirectory = id: {
    kpomo = "kpomo";
    kreate = "kreate";
    kships = "KShips";
    kwordle = "kwordle";
  }.${id};
  wafLegacyPath = id: {
    kpomo = "documents/kpomo";
    kreate = "documents/kreate";
    kships = "documents/KShips";
    kwordle = "documents/kwordle";
  }.${id};
  checkArtifact = artifact: ''
    ARCHIVE=${lib.escapeShellArg "${artifact}/${artifact.kpm.filename}"}
    test "$(${lib.getExe pkgs.gnutar} -xOf "''${ARCHIVE}" ./manifest.json)" = ${lib.escapeShellArg artifact.kpm.manifest}
    ${lib.getExe pkgs.gnutar} -tzf "''${ARCHIVE}" > archive-members
    test "$(sort archive-members | uniq -d | wc -l)" -eq 0
    if grep -Eq '^/|(^|/)\.\.(/|$)' archive-members; then
      exit 1
    fi
    rm -rf extracted
    mkdir extracted
    ${lib.getExe pkgs.gnutar} -xzf "''${ARCHIVE}" -C extracted
    if grep -RIl ${lib.escapeShellArg "/nix/store/"} extracted/install.sh extracted/uninstall.sh extracted/launch.sh 2>/dev/null; then
      exit 1
    fi
    for HOOK in install.sh uninstall.sh launch.sh; do
      if test -f "extracted/''${HOOK}"; then
        sh -n "extracted/''${HOOK}"
        ${lib.getExe pkgs.shellcheck} --shell=sh --severity=error "extracted/''${HOOK}"
      fi
    done
    ${lib.optionalString (lib.elem artifact.kpm.id [
      "kpomo"
      "kreate"
      "kships"
      "kwordle"
    ]) ''
      FIXTURE_DIRECTORY="''${WORK_DIRECTORY}/fixture-${artifact.kpm.id}"
      mkdir -p "''${FIXTURE_DIRECTORY}/etc" "''${FIXTURE_DIRECTORY}/var/local"
      printf '%s\n' 'Kindle 5.16.2.1.1' > "''${FIXTURE_DIRECTORY}/etc/prettyversion.txt"
      sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" \
        'CREATE TABLE handlerIds(handlerId TEXT PRIMARY KEY); CREATE TABLE properties(handlerId TEXT, name TEXT, value TEXT);'
      sed \
        -e "s#/var/local#''${FIXTURE_DIRECTORY}/var/local#g" \
        -e "s#/mnt/us#''${FIXTURE_DIRECTORY}/mnt/us#g" \
        -e "s#/etc/prettyversion.txt#''${FIXTURE_DIRECTORY}/etc/prettyversion.txt#g" \
        extracted/install.sh > fixture-install.sh
      sed \
        -e "s#/var/local#''${FIXTURE_DIRECTORY}/var/local#g" \
        extracted/uninstall.sh > fixture-uninstall.sh
      (cd extracted && sh ../fixture-install.sh)
      test -f "''${FIXTURE_DIRECTORY}/var/local/mesquite/${wafDirectory artifact.kpm.id}/.kpm-${artifact.kpm.id}"
      test "$(sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" 'SELECT COUNT(*) FROM handlerIds;')" -eq 1
      (cd extracted && sh ../fixture-uninstall.sh upgrade)
      test -f "''${FIXTURE_DIRECTORY}/var/local/mesquite/${wafDirectory artifact.kpm.id}/.kpm-${artifact.kpm.id}"
      (cd extracted && sh ../fixture-install.sh upgrade)
      (cd extracted && sh ../fixture-uninstall.sh)
      test "$(sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" 'SELECT COUNT(*) FROM handlerIds;')" -eq 0
      mkdir -p "''${FIXTURE_DIRECTORY}/var/local/mesquite/${wafDirectory artifact.kpm.id}"
      if (cd extracted && sh ../fixture-install.sh); then
        exit 1
      fi
      rm -rf "''${FIXTURE_DIRECTORY}/var/local/mesquite/${wafDirectory artifact.kpm.id}"
      mkdir -p "''${FIXTURE_DIRECTORY}/mnt/us/${wafLegacyPath artifact.kpm.id}"
      if (cd extracted && sh ../fixture-install.sh); then
        exit 1
      fi
      test -d "''${FIXTURE_DIRECTORY}/mnt/us/${wafLegacyPath artifact.kpm.id}"
      test "$(sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" 'SELECT COUNT(*) FROM handlerIds;')" -eq 0
    ''}
  '';
in
pkgs.runCommand "kpm-repository-check"
{
  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnutar
    pkgs.jq
    pkgs.shellcheck
    pkgs.sqlite
  ];
}
  ''
    OUTPUT_PATH=${lib.escapeShellArg (builtins.placeholder "out")}
    WORK_DIRECTORY="$(${lib.getExe' pkgs.coreutils "mktemp"} -d)"
    trap '${lib.getExe' pkgs.coreutils "rm"} -rf "''${WORK_DIRECTORY}"' EXIT
    cd "''${WORK_DIRECTORY}"
    ${lib.concatMapStrings checkArtifact artifacts}
    MANIFEST=${repository}/manifest.v2.json
    ${lib.getExe pkgs.jq} -e '
      .manifest_version == 2
      and (.id | type == "string" and length > 0)
      and (.name | type == "string" and length > 0)
      and (.description | type == "string")
      and (.packages | type == "object")
      and ((.packages | keys) == ["gargoyle", "kpomo", "kreate", "kships", "kwordle", "larkplayer", "toggleads", "updateblockstatus"])
      and ([.packages[].artifacts[]] | length == 9)
      and all(.packages[];
        (.name | type == "string" and length > 0)
        and (.author | type == "string" and length > 0)
        and (.description | type == "string")
        and (.artifacts | type == "array" and length > 0)
        and all(.artifacts[];
          (.url | type == "string")
          and (.version | type == "array" and length == 3 and all(.[]; type == "number" and . >= 0))
          and (.dependencies | type == "array")
          and (.supported_platforms | type == "array" and length > 0)
          and all(.supported_platforms[]; IN("kindle", "kindle5", "kindlepw2", "kindlehf"))
        )
      )
    ' "''${MANIFEST}" > /dev/null
    ${lib.getExe pkgs.jq} -r '.packages[].artifacts[].url' "''${MANIFEST}" | while IFS= read -r URL; do
      test -f "${repository}/''${URL}"
    done
    touch "''${OUTPUT_PATH}"
  ''
