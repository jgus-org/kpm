{ lib, pkgs }:
{ artifacts, repository }:
let
  expectedArtifactCount = builtins.length artifacts;
  expectedPackageIds = lib.sort builtins.lessThan (
    lib.unique (map (artifact: artifact.kpm.id) artifacts)
  );
  packageChecks = lib.concatMap (artifact: builtins.attrValues (artifact.passthru.tests or { })) artifacts;
  kpmLaunchStub =
    artifact:
    pkgs.writeShellScript "kpm-launch-${artifact.kpm.id}" ''
      set -eu
      test "''${#}" -ge 2
      test "''${1}" = launch
      test "''${2}" = ${lib.escapeShellArg artifact.kpm.id}
      test -f "''${KPM_LAUNCH_ENTRY}"
      touch "''${KPM_LAUNCH_RECORDED}"
    '';
  checkNativeScriptlet = artifact: scriptlet: ''
    SCRIPTLET=${lib.escapeShellArg "extracted/${scriptlet.source}"}
    INSTALLED_SCRIPTLET="''${FIXTURE_DIRECTORY}${scriptlet.destination}"
    test -f "''${SCRIPTLET}"
    test -f "''${INSTALLED_SCRIPTLET}"
    cmp "''${SCRIPTLET}" "''${INSTALLED_SCRIPTLET}"
    sed "s#/var/local/kmc/bin/kpm#''${KPM_STUB}#g" "''${SCRIPTLET}" > consumer-scriptlet
    rm -f "''${KPM_LAUNCH_RECORDED}"
    sh consumer-scriptlet
    test -f "''${KPM_LAUNCH_RECORDED}"
  '';
  assertNativeScriptletsAbsent =
    artifact:
    lib.concatMapStrings
      (scriptlet: ''
        test ! -e "''${FIXTURE_DIRECTORY}${scriptlet.destination}"
      '')
      artifact.native.scriptlets;
  initializePreservedPaths =
    artifact:
    lib.concatMapStrings
      (path: ''
        mkdir -p "$(dirname "''${FIXTURE_DIRECTORY}${artifact.native.destination}/${path}")"
        printf '%s' preserved > "''${FIXTURE_DIRECTORY}${artifact.native.destination}/${path}"
      '')
      artifact.native.preservedPaths;
  assertPreservedPaths =
    artifact:
    lib.concatMapStrings
      (path: ''
        test "$(cat "''${FIXTURE_DIRECTORY}${artifact.native.destination}/${path}")" = preserved
      '')
      artifact.native.preservedPaths;
  createNativeScriptletCollisions =
    artifact:
    lib.concatMapStrings
      (scriptlet: ''
        mkdir -p "$(dirname "''${FIXTURE_DIRECTORY}${scriptlet.destination}")"
        mkdir "''${FIXTURE_DIRECTORY}${scriptlet.destination}"
        printf '%s' foreign > "''${FIXTURE_DIRECTORY}${scriptlet.destination}/value"
      '')
      artifact.native.scriptlets;
  assertNativeScriptletCollisions =
    artifact:
    lib.concatMapStrings
      (scriptlet: ''
        test "$(cat "''${FIXTURE_DIRECTORY}${scriptlet.destination}/value")" = foreign
      '')
      artifact.native.scriptlets;
  removeNativeScriptletCollisions =
    artifact:
    lib.concatMapStrings
      (scriptlet: ''
        rm -rf "''${FIXTURE_DIRECTORY}${scriptlet.destination}"
      '')
      artifact.native.scriptlets;
  checkWafLegacyCollision =
    artifact:
    let
      legacyPaths = lib.filter
        (path: !(artifact.waf ? documents) || artifact.waf.documents == null || path != artifact.waf.documents.directory)
        artifact.waf.legacyPaths;
    in
    lib.optionalString (legacyPaths != [ ]) ''
      mkdir -p "''${FIXTURE_DIRECTORY}${builtins.head legacyPaths}"
      if (cd extracted && sh ../fixture-install.sh); then
        exit 1
      fi
      test -d "''${FIXTURE_DIRECTORY}${builtins.head legacyPaths}"
      test "$(sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" 'SELECT COUNT(*) FROM handlerIds;')" -eq 0
      rm -rf "''${FIXTURE_DIRECTORY}${builtins.head legacyPaths}"
    '';
  checkWafLifecyclePreludes =
    artifact:
    lib.optionalString artifact.waf.lifecycleFailureFixture ''
      CALLBACK_DIRECTORY="''${WORK_DIRECTORY}/waf-callback-${artifact.kpm.id}"
      mkdir -p "''${CALLBACK_DIRECTORY}/bin"
      printf '%s\n' '#!/bin/sh' 'exit 0' > "''${CALLBACK_DIRECTORY}/bin/pgrep"
      printf '%s\n' '#!/bin/sh' 'exit 0' > "''${CALLBACK_DIRECTORY}/bin/sleep"
      chmod 755 "''${CALLBACK_DIRECTORY}/bin/pgrep" "''${CALLBACK_DIRECTORY}/bin/sleep"
      rm -rf callback-extracted
      cp -R extracted callback-extracted
      rm -f callback-extracted/.kpm-install-success callback-extracted/.kpm-install-success.pending
      if ! (cd callback-extracted && PATH="''${CALLBACK_DIRECTORY}/bin:''${PATH}" sh ../fixture-uninstall.sh); then
        exit 1
      fi
      test "$(cat "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}")" = active
      if (cd extracted && PATH="''${CALLBACK_DIRECTORY}/bin:''${PATH}" sh ../fixture-uninstall.sh upgrade); then
        exit 1
      fi
      test "$(cat "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}")" = active
      if (cd extracted && PATH="''${CALLBACK_DIRECTORY}/bin:''${PATH}" sh ../fixture-install.sh upgrade); then
        exit 1
      fi
      test "$(cat "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}")" = active
    '';
  checkWafDocuments = artifact: ''
    DOCUMENTS_FIXTURE_DIRECTORY="''${WORK_DIRECTORY}/documents-fixture-${artifact.kpm.id}"
    mkdir -p "''${DOCUMENTS_FIXTURE_DIRECTORY}/etc" "''${DOCUMENTS_FIXTURE_DIRECTORY}/var/local"
    printf '%s\n' 'Kindle 5.16.2.1.1' > "''${DOCUMENTS_FIXTURE_DIRECTORY}/etc/prettyversion.txt"
    sqlite3 "''${DOCUMENTS_FIXTURE_DIRECTORY}/var/local/appreg.db" \
      'CREATE TABLE handlerIds(handlerId TEXT PRIMARY KEY); CREATE TABLE properties(handlerId TEXT, name TEXT, value TEXT);'
    sed \
      -e "s#/var/local#''${DOCUMENTS_FIXTURE_DIRECTORY}/var/local#g" \
      -e "s#/mnt/us#''${DOCUMENTS_FIXTURE_DIRECTORY}/mnt/us#g" \
      -e "s#/etc/prettyversion.txt#''${DOCUMENTS_FIXTURE_DIRECTORY}/etc/prettyversion.txt#g" \
      extracted/install.sh > documents-install.sh
    sed \
      -e "s#/var/local#''${DOCUMENTS_FIXTURE_DIRECTORY}/var/local#g" \
      -e "s#/mnt/us#''${DOCUMENTS_FIXTURE_DIRECTORY}/mnt/us#g" \
      extracted/uninstall.sh > documents-uninstall.sh
    (cd extracted && sh ../documents-install.sh)
    test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}")" = active
    test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/.kpm-${artifact.kpm.id}")" = active
    ${lib.concatMapStrings (path: ''
      mkdir -p "$(dirname "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}")"
      if [ -d "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}" ]; then
        printf '%s' preserved > "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}/fixture-state"
      else
        printf '%s' preserved > "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}"
      fi
    '') artifact.waf.documents.retainedPaths}
    (cd extracted && sh ../documents-uninstall.sh upgrade)
    test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}")" = handoff
    test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/.kpm-${artifact.kpm.id}")" = handoff
    (cd extracted && sh ../documents-install.sh upgrade)
    ${lib.concatMapStrings (path: ''
      if [ -d "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}" ]; then
        test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}/fixture-state")" = preserved
      else
        test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}")" = preserved
      fi
    '') artifact.waf.documents.retainedPaths}
    (cd extracted && sh ../documents-uninstall.sh)
    test ! -e "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}"
    test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/.kpm-${artifact.kpm.id}")" = retained
    (cd extracted && sh ../documents-install.sh)
    ${lib.concatMapStrings (path: ''
      if [ -d "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}" ]; then
        test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}/fixture-state")" = preserved
      else
        test "$(cat "''${DOCUMENTS_FIXTURE_DIRECTORY}${artifact.waf.documents.directory}/${path}")" = preserved
      fi
    '') artifact.waf.documents.retainedPaths}
  '';
  checkNativeArtifact = artifact: ''
    FIXTURE_DIRECTORY="''${WORK_DIRECTORY}/fixture-${artifact.kpm.id}"
    KPM_STUB=${lib.escapeShellArg (kpmLaunchStub artifact)}
    KPM_LAUNCH_ENTRY=extracted/launch.sh
    KPM_LAUNCH_RECORDED="''${WORK_DIRECTORY}/kpm-launch-${artifact.kpm.id}"
    export KPM_LAUNCH_ENTRY KPM_LAUNCH_RECORDED
    rm -rf "''${FIXTURE_DIRECTORY}"
    mkdir -p "''${FIXTURE_DIRECTORY}${dirOf artifact.native.destination}" "''${FIXTURE_DIRECTORY}/mnt/us/documents"
    sed -e "s#/mnt/us#''${FIXTURE_DIRECTORY}/mnt/us#g" extracted/install.sh > fixture-install.sh
    sed -e "s#/mnt/us#''${FIXTURE_DIRECTORY}/mnt/us#g" extracted/uninstall.sh > fixture-uninstall.sh
    (cd extracted && sh ../fixture-install.sh)
    test -f "''${FIXTURE_DIRECTORY}${artifact.native.marker}"
    ${lib.concatMapStrings (checkNativeScriptlet artifact) artifact.native.scriptlets}
    ${initializePreservedPaths artifact}
    mkdir -p "''${FIXTURE_DIRECTORY}${artifact.native.destination}/user-save"
    printf '%s' user > "''${FIXTURE_DIRECTORY}${artifact.native.destination}/user-save/value"
    (cd extracted && sh ../fixture-uninstall.sh upgrade)
    test -f "''${FIXTURE_DIRECTORY}${artifact.native.marker}"
    ${assertNativeScriptletsAbsent artifact}
    ${assertPreservedPaths artifact}
    test "$(cat "''${FIXTURE_DIRECTORY}${artifact.native.destination}/user-save/value")" = user
    (cd extracted && sh ../fixture-install.sh upgrade)
    ${lib.concatMapStrings (checkNativeScriptlet artifact) artifact.native.scriptlets}
    ${assertPreservedPaths artifact}
    (cd extracted && sh ../fixture-uninstall.sh upgrade)
    ${lib.optionalString (artifact.native.scriptlets != [ ]) ''
      ${createNativeScriptletCollisions artifact}
      if (cd extracted && sh ../fixture-install.sh upgrade); then
        exit 1
      fi
      test -f "''${FIXTURE_DIRECTORY}${artifact.native.marker}"
      ${assertNativeScriptletCollisions artifact}
      ${assertPreservedPaths artifact}
      test "$(cat "''${FIXTURE_DIRECTORY}${artifact.native.destination}/user-save/value")" = user
      (cd extracted && sh ../fixture-uninstall.sh)
      test -f "''${FIXTURE_DIRECTORY}${artifact.native.marker}"
      ${assertNativeScriptletCollisions artifact}
      ${assertPreservedPaths artifact}
      test "$(cat "''${FIXTURE_DIRECTORY}${artifact.native.destination}/user-save/value")" = user
      ${removeNativeScriptletCollisions artifact}
    ''}
    (cd extracted && sh ../fixture-install.sh upgrade)
    (cd extracted && sh ../fixture-uninstall.sh)
    ${assertPreservedPaths artifact}
    test "$(cat "''${FIXTURE_DIRECTORY}${artifact.native.destination}/user-save/value")" = user
    (cd extracted && sh ../fixture-uninstall.sh)
    rm -rf "''${FIXTURE_DIRECTORY}"
    mkdir -p "''${FIXTURE_DIRECTORY}${artifact.native.destination}"
    printf '%s' foreign > "''${FIXTURE_DIRECTORY}${artifact.native.destination}/foreign"
    if (cd extracted && sh ../fixture-install.sh); then
      exit 1
    fi
    test "$(cat "''${FIXTURE_DIRECTORY}${artifact.native.destination}/foreign")" = foreign
    rm -rf "''${FIXTURE_DIRECTORY}"
    mkdir -p "''${FIXTURE_DIRECTORY}${dirOf artifact.native.destination}" "''${FIXTURE_DIRECTORY}/mnt/us/documents"
    ${lib.concatMapStrings (scriptlet: ''
      printf '%s' foreign > "''${FIXTURE_DIRECTORY}${scriptlet.destination}"
    '') artifact.native.scriptlets}
    if (cd extracted && sh ../fixture-install.sh); then
      exit 1
    fi
    ${lib.concatMapStrings (scriptlet: ''
      test "$(cat "''${FIXTURE_DIRECTORY}${scriptlet.destination}")" = foreign
    '') artifact.native.scriptlets}
  '';
  checkArtifact = artifact: ''
    ARCHIVE=${lib.escapeShellArg "${artifact}/${artifact.kpm.filename}"}
    test "$(${lib.getExe pkgs.gnutar} -xOf "''${ARCHIVE}" manifest.json)" = ${lib.escapeShellArg artifact.kpm.manifest}
    test "$(${lib.getExe pkgs.gnutar} -xOf "''${ARCHIVE}" manifest.json | ${lib.getExe pkgs.jq} -r .manifest_version)" -eq 2
    ${lib.getExe pkgs.gnutar} -tzf "''${ARCHIVE}" > archive-members
    ${lib.getExe pkgs.gnutar} -tvzf "''${ARCHIVE}" > archive-member-details
    if grep -Eq '^[lh]' archive-member-details; then
      exit 1
    fi
    if grep -Eq '^\./' archive-members; then
      exit 1
    fi
    test "$(sort archive-members | uniq -d | wc -l)" -eq 0
    if grep -Eq '^/|(^|/)\.\.(/|$)' archive-members; then
      exit 1
    fi
    rm -rf extracted
    mkdir extracted
    ${lib.getExe pkgs.gnutar} -xzf "''${ARCHIVE}" -C extracted
    if grep -RIl ${lib.escapeShellArg "/nix/store/"} \
      extracted/install.sh extracted/uninstall.sh extracted/launch.sh extracted/scriptlets 2>/dev/null; then
      exit 1
    fi
    for HOOK in install.sh uninstall.sh launch.sh; do
      if test -f "extracted/''${HOOK}"; then
        sh -n "extracted/''${HOOK}"
        ${lib.getExe pkgs.shellcheck} --shell=sh --severity=error "extracted/''${HOOK}"
      fi
    done
    ${lib.optionalString (artifact ? scriptlet) ''
      SCRIPTLET=${lib.escapeShellArg "extracted/${artifact.scriptlet.path or "scriptlets/${artifact.scriptlet.name}"}"}
      LAUNCH_ENTRY=extracted/launch.sh
      test -f "''${SCRIPTLET}"
      test -f "''${LAUNCH_ENTRY}"
      sh -n "''${SCRIPTLET}"
      KPM_STUB=${lib.escapeShellArg (kpmLaunchStub artifact)}
      export KPM_LAUNCH_ENTRY="''${LAUNCH_ENTRY}"
      KPM_LAUNCH_RECORDED="''${WORK_DIRECTORY}/kpm-launch-${artifact.kpm.id}"
      export KPM_LAUNCH_RECORDED
      rm -f "''${KPM_LAUNCH_RECORDED}"
      sed "s#/var/local/kmc/bin/kpm#''${KPM_STUB}#g" "''${SCRIPTLET}" > consumer-scriptlet
      sh consumer-scriptlet
      test -f "''${KPM_LAUNCH_RECORDED}"
    ''}
    ${lib.optionalString (artifact ? scriptlet && artifact.scriptlet ? installedIcon) ''
      SCRIPTLET=${lib.escapeShellArg "extracted/${artifact.scriptlet.path or "scriptlets/${artifact.scriptlet.name}"}"}
      ICON_LINE="$(sed -n '1,6{s/^# Icon: //p;}' "''${SCRIPTLET}")"
      test "$(printf '%s\n' "''${ICON_LINE}" | wc -l)" -eq 1
      test "''${ICON_LINE}" = ${lib.escapeShellArg artifact.scriptlet.installedIcon}
      case "$( ${lib.getExe' pkgs.imagemagick "identify"} -format '%m' ${lib.escapeShellArg "extracted/${artifact.scriptlet.icon}"})" in
        PNG|JPEG) ;;
        *) exit 1 ;;
      esac
    ''}
    ${lib.optionalString
      (artifact ? scriptlet && artifact.scriptlet ? icon && artifact.scriptlet.icon != null && !(artifact.scriptlet ? installedIcon))
      ''
        SCRIPTLET=${lib.escapeShellArg "extracted/${artifact.scriptlet.path or "scriptlets/${artifact.scriptlet.name}"}"}
        ICON_LINE="$(sed -n '1,6{s/^# Icon: //p;}' "''${SCRIPTLET}")"
        test "$(printf '%s\n' "''${ICON_LINE}" | wc -l)" -eq 1
        case "''${ICON_LINE}" in
          data:image/png\;base64,*|data:image/jpeg\;base64,*) ;;
          *) exit 1 ;;
        esac
        printf '%s' "''${ICON_LINE#*,}" | ${lib.getExe' pkgs.coreutils "base64"} --decode > decoded-icon
        case "''${ICON_LINE}:$(${lib.getExe' pkgs.imagemagick "identify"} -format '%m' decoded-icon)" in
          data:image/png\;base64,*:PNG|data:image/jpeg\;base64,*:JPEG) ;;
          *) exit 1 ;;
        esac
        ${lib.optionalString (artifact.scriptlet.icon != null) ''
          cmp decoded-icon ${lib.escapeShellArg "extracted/${artifact.scriptlet.icon}"}
        ''}
      ''
    }
    ${lib.optionalString (artifact ? waf) ''
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
        -e "s#/mnt/us#''${FIXTURE_DIRECTORY}/mnt/us#g" \
        extracted/uninstall.sh > fixture-uninstall.sh
      (cd extracted && sh ../fixture-install.sh)
      test -f "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}"
      test -f "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      cmp "extracted/scriptlets/${artifact.waf.scriptletName}" \
        "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      grep -Fx ${lib.escapeShellArg "exec /var/local/kmc/bin/kpm launch ${artifact.kpm.id}"} \
        "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      test "$(sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" 'SELECT COUNT(*) FROM handlerIds;')" -eq 1
      ${checkWafLifecyclePreludes artifact}
      rm "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      (cd extracted && sh ../fixture-install.sh)
      test -f "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      (cd extracted && sh ../fixture-uninstall.sh upgrade)
      test -f "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}/.kpm-${artifact.kpm.id}"
      test ! -e "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      (cd extracted && sh ../fixture-install.sh upgrade)
      test -f "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      (cd extracted && sh ../fixture-uninstall.sh)
      test "$(sqlite3 "''${FIXTURE_DIRECTORY}/var/local/appreg.db" 'SELECT COUNT(*) FROM handlerIds;')" -eq 0
      test ! -e "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      rm -rf old-extracted
      cp -R extracted old-extracted
      chmod u+w "old-extracted/scriptlets/${artifact.waf.scriptletName}"
      printf '%s\n' '# DontUseFBInk' \
        ${lib.escapeShellArg "exec /var/local/kmc/bin/kpm launch ${artifact.kpm.id} old"} \
        > "old-extracted/scriptlets/${artifact.waf.scriptletName}"
      (cd old-extracted && sh ../fixture-install.sh)
      (cd old-extracted && sh ../fixture-uninstall.sh upgrade)
      test ! -e "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      (cd extracted && sh ../fixture-install.sh upgrade)
      cmp "extracted/scriptlets/${artifact.waf.scriptletName}" \
        "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      (cd extracted && sh ../fixture-uninstall.sh)
      rm -rf "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}"
      mkdir -p "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}"
      if (cd extracted && sh ../fixture-install.sh); then
        exit 1
      fi
      rm -rf "''${FIXTURE_DIRECTORY}${artifact.waf.mesquiteDirectory}"
      ${checkWafLegacyCollision artifact}
      mkdir -p "''${FIXTURE_DIRECTORY}/mnt/us/documents"
      printf '%s\n' foreign > "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}"
      if (cd extracted && sh ../fixture-install.sh); then
        exit 1
      fi
      test "$(cat "''${FIXTURE_DIRECTORY}/mnt/us/documents/${artifact.waf.scriptletName}")" = foreign
    ''}
    ${lib.optionalString (artifact ? native) (checkNativeArtifact artifact)}
    ${lib.optionalString (artifact ? waf && artifact.waf ? documents && artifact.waf.documents != null) (checkWafDocuments artifact)}
  '';
in
pkgs.runCommand "kpm-repository-check"
{
  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnutar
    pkgs.imagemagick
    pkgs.jq
    pkgs.shellcheck
    pkgs.sqlite
    pkgs.util-linux
  ] ++ packageChecks;
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
      and ((.packages | keys) == ${builtins.toJSON expectedPackageIds})
      and ([.packages[].artifacts[]] | length == ${toString expectedArtifactCount})
      and all(.packages[];
        (.name | type == "string" and length > 0)
        and (.author | type == "string" and length > 0)
        and (.description | type == "string")
        and (.artifacts | type == "array" and length > 0)
        and all(.artifacts[];
          (.url | type == "string")
          and (.version | type == "array" and length == 3 and all(.[]; type == "number" and . >= 0))
          and (.dependencies | type == "array"
            and all(.
              []; (.id | type == "string" and length > 0)
              and ((has("min") | not) or (.min | type == "array" and length == 3 and all(.[]; type == "number" and . >= 0)))
              and ((has("max") | not) or (.max | type == "array" and length == 3 and all(.[]; type == "number" and . >= 0)))
            )
          )
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
