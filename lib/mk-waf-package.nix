{ mkKpackage, writeTextFile }:
{ id
, name
, author
, description
, version
, platforms
, src
, buildPayload
, payloadDirectory
, mesquiteDirectory
, appId
, scriptletName
, legacyPaths
, scriptletIcon ? null
, legacyPayloadDirectory ? null
, legacyFirmwareMaximum ? null
, retainedPayloadPaths ? [ ]
, documents ? null
, launchPrelude ? ""
, installPrelude ? ""
, uninstallPrelude ? ""
, lifecycleFailureFixture ? false
, passthru ? { }
,
}:
assert (legacyPayloadDirectory == null) == (legacyFirmwareMaximum == null);
assert legacyFirmwareMaximum == null || builtins.length legacyFirmwareMaximum == 4;
assert builtins.isBool lifecycleFailureFixture;
assert scriptletIcon == null || (
  builtins.isString scriptletIcon.path
    && builtins.match "[a-z0-9.+-]+" scriptletIcon.mediaSubtype != null
);
assert builtins.all
  (path:
  builtins.isString path
    && builtins.match "([A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)*" path != null
  )
  retainedPayloadPaths;
assert builtins.all
  (path:
  builtins.length (builtins.filter (candidate: candidate == path) retainedPayloadPaths) == 1
  )
  retainedPayloadPaths;
assert builtins.all
  (parent:
  builtins.all
    (child:
    parent == child || builtins.match "${parent}/.*" child == null
    )
    retainedPayloadPaths
  )
  retainedPayloadPaths;
assert documents == null || (
  documents ? directory
    && documents ? payloadDirectory
    && documents ? retainedPaths
    && builtins.isString documents.directory
    && (documents.payloadDirectory == null || builtins.isString documents.payloadDirectory)
    && builtins.all
    (path:
      builtins.isString path
        && builtins.match "([A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)*" path != null
    )
    documents.retainedPaths
    && builtins.all
    (path:
      builtins.length (builtins.filter (candidate: candidate == path) documents.retainedPaths) == 1
    )
    documents.retainedPaths
    && builtins.all
    (parent:
      builtins.all
        (child:
          parent == child || builtins.match "${parent}/.*" child == null
        )
        documents.retainedPaths
    )
    documents.retainedPaths
);
assert documents == null || retainedPayloadPaths == [ ] || documents.retainedPaths == [ ];
let
  mesquiteParent = builtins.dirOf mesquiteDirectory;
  documentsParent = if documents == null then null else builtins.dirOf documents.directory;
  documentsRetainedPaths = if documents == null then [ ] else documents.retainedPaths;
  documentsPayloadDirectory = if documents == null || documents.payloadDirectory == null then payloadDirectory else documents.payloadDirectory;
  documentsUsesSelectedPayload = documents != null && documents.payloadDirectory == null;
  firstPathComponent = path: builtins.elemAt (builtins.match "([^/]+).*" path) 0;
  retainedPayloadCopy = builtins.concatStringsSep "\n" (map
    (path: ''
      if [ -e "''${RETAINED_SOURCE}/${path}" ] || [ -L "''${RETAINED_SOURCE}/${path}" ]; then
        rm -rf "''${RETAINED_DESTINATION}/${path}"
        mkdir -p "''${RETAINED_DESTINATION}/${builtins.dirOf path}"
        cp -R "''${RETAINED_SOURCE}/${path}" "''${RETAINED_DESTINATION}/${path}"
      fi
    '')
    retainedPayloadPaths);
  retainedShapePatterns = builtins.concatStringsSep "|" (map
    (path: "'${mesquiteDirectory}/${firstPathComponent path}'")
    retainedPayloadPaths
  );
  documentsRetainedPayloadCopy = builtins.concatStringsSep "\n" (map
    (path: ''
      if [ -e "''${DOCUMENTS_RETAINED_SOURCE}/${path}" ] || [ -L "''${DOCUMENTS_RETAINED_SOURCE}/${path}" ]; then
        rm -rf "''${DOCUMENTS_RETAINED_DESTINATION}/${path}"
        mkdir -p "''${DOCUMENTS_RETAINED_DESTINATION}/${builtins.dirOf path}"
        cp -R "''${DOCUMENTS_RETAINED_SOURCE}/${path}" "''${DOCUMENTS_RETAINED_DESTINATION}/${path}"
      fi
    '')
    documentsRetainedPaths);
  documentsRetainedShapePatterns = if documents == null then "" else
  builtins.concatStringsSep "|" (map
    (path: "'${documents.directory}/${firstPathComponent path}'")
    documentsRetainedPaths
  );
  scriptletBody = writeTextFile {
    name = "${id}-scriptlet.sh";
    text = ''
      # DontUseFBInk
      exec /var/local/kmc/bin/kpm launch ${id}
    '';
  };
  unownedLegacyPaths = builtins.filter
    (path:
      (documents == null || path != documents.directory)
      && path != "/mnt/us/documents/${scriptletName}"
    )
    legacyPaths;
  legacyCollision = builtins.concatStringsSep " || " (map (path: "{ [ -e '${path}' ] || [ -L '${path}' ]; }") unownedLegacyPaths);
in
(mkKpackage {
  inherit id name author description version platforms src passthru;
  scriptlet =
    if scriptletIcon == null then {
      name = scriptletName;
    } else {
      name = scriptletName;
      icon = scriptletIcon.path;
    };
  buildPayload = ''
    ${buildPayload}
    mkdir -p scriptlets
    ${if scriptletIcon == null then
      "cp '${scriptletBody}' 'scriptlets/${scriptletName}'"
    else ''
      printf '%s' '# Icon: data:image/${scriptletIcon.mediaSubtype};base64,' > 'scriptlets/${scriptletName}'
      base64 --wrap=0 '${scriptletIcon.path}' >> 'scriptlets/${scriptletName}'
      printf '\n' >> 'scriptlets/${scriptletName}'
      cat '${scriptletBody}' >> 'scriptlets/${scriptletName}'
    ''}
  '';
  installScript = builtins.toFile "${id}-install.sh" ''
    set -eu
    : > .kpm-install-success.pending
    MARKER='${mesquiteDirectory}/.kpm-${id}'
    SCRIPTLET='/mnt/us/documents/${scriptletName}'
    SCRIPTLET_STAGE='/mnt/us/documents/.kpm-${id}-scriptlet-''${$}'
    STAGING_DIRECTORY='${mesquiteParent}/.kpm-${id}-stage-''${$}'
    BACKUP_DIRECTORY='${mesquiteParent}/.kpm-${id}-backup-''${$}'
    HAD_OWNED_DEPLOYMENT=0
    MARKER_STATE=
    SCRIPTLET_REPLACED=0
    ${if documents == null then "" else ''
      DOCUMENTS_MARKER='${documents.directory}/.kpm-${id}'
      DOCUMENTS_STAGING_DIRECTORY='${documentsParent}/.kpm-${id}-documents-stage-''${$}'
      DOCUMENTS_BACKUP_DIRECTORY='${documentsParent}/.kpm-${id}-documents-backup-''${$}'
      HAD_OWNED_DOCUMENTS=0
      DOCUMENTS_MARKER_STATE=
    ''}
    ${if unownedLegacyPaths == [ ] then "" else ''
      if { ${legacyCollision}; }; then
        echo 'a KindleForge ${id} deployment already exists' >&2
        exit 1
      fi
    ''}
    if [ -L "''${SCRIPTLET}" ] || { [ -e "''${SCRIPTLET}" ] && ! cmp -s 'scriptlets/${scriptletName}' "''${SCRIPTLET}"; }; then
      echo 'existing ${scriptletName} is not owned by this package' >&2
      exit 1
    fi
    HANDLER_COUNT="$(sqlite3 /var/local/appreg.db "SELECT COUNT(*) FROM handlerIds WHERE handlerId = '${appId}';")"
    if [ -L "''${MARKER}" ]; then
      echo 'owned ${id} marker has an invalid state' >&2
      exit 1
    fi
    if [ -L '${mesquiteDirectory}' ]; then
      echo 'existing ${appId} installation is not owned by this package' >&2
      exit 1
    fi
    if [ ! -f "''${MARKER}" ] && { [ -e '${mesquiteDirectory}' ] || [ -L '${mesquiteDirectory}' ] || [ "''${HANDLER_COUNT}" != 0 ]; }; then
      echo 'existing ${appId} installation is not owned by this package' >&2
      exit 1
    fi
    if [ -f "''${MARKER}" ]; then
      HAD_OWNED_DEPLOYMENT=1
      MARKER_STATE="$(cat "''${MARKER}")"
      if [ -n "''${MARKER_STATE}" ]; then
        case "''${MARKER_STATE}" in
          active|handoff|retained) ;;
          *)
            echo 'owned ${id} marker has an invalid state' >&2
            exit 1
            ;;
        esac
      fi
      ${if retainedPayloadPaths == [ ] then "" else ''
        if [ "''${MARKER_STATE}" = retained ]; then
          for ENTRY in '${mesquiteDirectory}'/* '${mesquiteDirectory}'/.[!.]* '${mesquiteDirectory}'/..?*; do
            [ -e "''${ENTRY}" ] || [ -L "''${ENTRY}" ] || continue
            case "''${ENTRY}" in
              "''${MARKER}"|${retainedShapePatterns}) ;;
              *)
                echo 'owned ${id} retained state has an unexpected path' >&2
                exit 1
                ;;
            esac
          done
        fi
      ''}
    fi
    ${if documents == null then "" else ''
      if [ -L "''${DOCUMENTS_MARKER}" ]; then
        echo 'owned ${id} Documents marker has an invalid state' >&2
        exit 1
      fi
      if [ -L '${documents.directory}' ]; then
        echo 'existing ${id} Documents tree is not owned by this package' >&2
        exit 1
      fi
      if { [ -e '${documents.directory}' ] || [ -L '${documents.directory}' ]; } && [ ! -f "''${DOCUMENTS_MARKER}" ]; then
        echo 'existing ${id} Documents tree is not owned by this package' >&2
        exit 1
      fi
      if [ -f "''${DOCUMENTS_MARKER}" ]; then
        HAD_OWNED_DOCUMENTS=1
        DOCUMENTS_MARKER_STATE="$(cat "''${DOCUMENTS_MARKER}")"
        if [ -n "''${DOCUMENTS_MARKER_STATE}" ]; then
          case "''${DOCUMENTS_MARKER_STATE}" in
            active|handoff|retained) ;;
            *)
              echo 'owned ${id} Documents marker has an invalid state' >&2
              exit 1
              ;;
          esac
        fi
        ${if documentsRetainedPaths == [ ] then "" else ''
          if [ "''${DOCUMENTS_MARKER_STATE}" = retained ]; then
            for ENTRY in '${documents.directory}'/* '${documents.directory}'/.[!.]* '${documents.directory}'/..?*; do
            [ -e "''${ENTRY}" ] || [ -L "''${ENTRY}" ] || continue
              case "''${ENTRY}" in
                "''${DOCUMENTS_MARKER}"|${documentsRetainedShapePatterns}) ;;
                *)
                  echo 'owned ${id} retained Documents state has an unexpected path' >&2
                  exit 1
                  ;;
              esac
            done
          fi
        ''}
      fi
    ''}
    PAYLOAD_DIRECTORY='${payloadDirectory}'
    ${if legacyPayloadDirectory == null then "" else ''
      FIRMWARE_VERSION="$(sed -n 's/^Kindle \([0-9][0-9.]*\).*/\1/p' /etc/prettyversion.txt)"
      if [ -z "''${FIRMWARE_VERSION}" ]; then
        echo 'firmware version is unavailable' >&2
        exit 1
      fi
      case "''${FIRMWARE_VERSION}" in
        *[!0-9.]*|*..*|.*|*.)
          echo 'firmware version is unavailable' >&2
          exit 1
          ;;
      esac
      FIRMWARE_MAJOR="$(printf '%s' "''${FIRMWARE_VERSION}" | cut -d. -f1)"
      FIRMWARE_MINOR="$(printf '%s' "''${FIRMWARE_VERSION}" | cut -d. -f2)"
      FIRMWARE_PATCH="$(printf '%s' "''${FIRMWARE_VERSION}" | cut -d. -f3)"
      FIRMWARE_BUILD="$(printf '%s' "''${FIRMWARE_VERSION}" | cut -d. -f4)"
      : "''${FIRMWARE_MINOR:=0}"
      : "''${FIRMWARE_PATCH:=0}"
      : "''${FIRMWARE_BUILD:=0}"
      if [ "''${FIRMWARE_MAJOR}" -lt ${toString (builtins.elemAt legacyFirmwareMaximum 0)} ] || \
        { [ "''${FIRMWARE_MAJOR}" -eq ${toString (builtins.elemAt legacyFirmwareMaximum 0)} ] && [ "''${FIRMWARE_MINOR}" -lt ${toString (builtins.elemAt legacyFirmwareMaximum 1)} ]; } || \
        { [ "''${FIRMWARE_MAJOR}" -eq ${toString (builtins.elemAt legacyFirmwareMaximum 0)} ] && [ "''${FIRMWARE_MINOR}" -eq ${toString (builtins.elemAt legacyFirmwareMaximum 1)} ] && [ "''${FIRMWARE_PATCH}" -lt ${toString (builtins.elemAt legacyFirmwareMaximum 2)} ]; } || \
        { [ "''${FIRMWARE_MAJOR}" -eq ${toString (builtins.elemAt legacyFirmwareMaximum 0)} ] && [ "''${FIRMWARE_MINOR}" -eq ${toString (builtins.elemAt legacyFirmwareMaximum 1)} ] && [ "''${FIRMWARE_PATCH}" -eq ${toString (builtins.elemAt legacyFirmwareMaximum 2)} ] && [ "''${FIRMWARE_BUILD}" -le ${toString (builtins.elemAt legacyFirmwareMaximum 3)} ]; }; then
        PAYLOAD_DIRECTORY='${legacyPayloadDirectory}'
      fi
    ''}
    ${installPrelude}
    cleanup() {
      rm -rf "''${STAGING_DIRECTORY}"
      rm -f "''${SCRIPTLET_STAGE}"
      if [ "''${SCRIPTLET_REPLACED}" -eq 1 ] && [ ! -L "''${SCRIPTLET}" ] && cmp -s 'scriptlets/${scriptletName}' "''${SCRIPTLET}"; then
        rm -f "''${SCRIPTLET}"
      fi
      if [ -e "''${BACKUP_DIRECTORY}" ]; then
        rm -rf '${mesquiteDirectory}'
        mv "''${BACKUP_DIRECTORY}" '${mesquiteDirectory}'
      elif [ "''${HAD_OWNED_DEPLOYMENT}" -eq 0 ]; then
        rm -rf '${mesquiteDirectory}'
        sqlite3 /var/local/appreg.db <<'SQL'
    DELETE FROM properties WHERE handlerId = '${appId}';
    DELETE FROM handlerIds WHERE handlerId = '${appId}';
    SQL
      fi
      ${if documents == null then "" else ''
        if [ -e "''${DOCUMENTS_BACKUP_DIRECTORY}" ]; then
          rm -rf '${documents.directory}'
          mv "''${DOCUMENTS_BACKUP_DIRECTORY}" '${documents.directory}'
        elif [ "''${HAD_OWNED_DOCUMENTS}" -eq 0 ]; then
          rm -rf '${documents.directory}'
        fi
      ''}
    }
    trap cleanup EXIT HUP INT TERM
    mkdir -p /mnt/us/documents
    cp 'scriptlets/${scriptletName}' "''${SCRIPTLET_STAGE}"
    mkdir -p '${mesquiteParent}'
    mkdir "''${STAGING_DIRECTORY}"
    cp -R "''${PAYLOAD_DIRECTORY}/." "''${STAGING_DIRECTORY}/"
    RETAINED_SOURCE='${mesquiteDirectory}'
    RETAINED_DESTINATION="''${STAGING_DIRECTORY}"
    ${retainedPayloadCopy}
    printf '%s' handoff > "''${STAGING_DIRECTORY}/.kpm-${id}"
    ${if documents == null then "" else ''
      mkdir -p '${documentsParent}'
      mkdir "''${DOCUMENTS_STAGING_DIRECTORY}"
      DOCUMENTS_PAYLOAD_DIRECTORY='${documentsPayloadDirectory}'
      ${if documentsUsesSelectedPayload then "DOCUMENTS_PAYLOAD_DIRECTORY=\"\${PAYLOAD_DIRECTORY}\"" else ""}
      cp -R "''${DOCUMENTS_PAYLOAD_DIRECTORY}/." "''${DOCUMENTS_STAGING_DIRECTORY}/"
      DOCUMENTS_RETAINED_SOURCE='${documents.directory}'
      DOCUMENTS_RETAINED_DESTINATION="''${DOCUMENTS_STAGING_DIRECTORY}"
      ${documentsRetainedPayloadCopy}
      printf '%s' handoff > "''${DOCUMENTS_STAGING_DIRECTORY}/.kpm-${id}"
    ''}
    if [ "''${HAD_OWNED_DEPLOYMENT}" -eq 1 ]; then
      mv '${mesquiteDirectory}' "''${BACKUP_DIRECTORY}"
    fi
    ${if documents == null then "" else ''
      if [ "''${HAD_OWNED_DOCUMENTS}" -eq 1 ]; then
        mv '${documents.directory}' "''${DOCUMENTS_BACKUP_DIRECTORY}"
      fi
    ''}
    mv "''${STAGING_DIRECTORY}" '${mesquiteDirectory}'
    ${if documents == null then "" else "mv \"\${DOCUMENTS_STAGING_DIRECTORY}\" '${documents.directory}'"}
    sqlite3 /var/local/appreg.db <<'SQL'
    INSERT OR IGNORE INTO handlerIds(handlerId) VALUES('${appId}');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'lipcId', '${appId}');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'command', '/usr/bin/mesquite -l ${appId} -c file://${mesquiteDirectory}/');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'supportedOrientation', 'U');
    SQL
    mv -f "''${SCRIPTLET_STAGE}" "''${SCRIPTLET}"
    SCRIPTLET_REPLACED=1
    printf '%s' active > "''${MARKER}"
    ${if documents == null then "" else "printf '%s' active > \"\${DOCUMENTS_MARKER}\""}
    mv .kpm-install-success.pending .kpm-install-success
    trap - EXIT HUP INT TERM
    rm -rf "''${BACKUP_DIRECTORY}"
    ${if documents == null then "" else "rm -rf \"\${DOCUMENTS_BACKUP_DIRECTORY}\""}
  '';
  uninstallScript = builtins.toFile "${id}-uninstall.sh" ''
    set -eu
    if [ ! -f .kpm-install-success ]; then
      rm -f .kpm-install-success.pending
      exit 0
    fi
    MARKER='${mesquiteDirectory}/.kpm-${id}'
    SCRIPTLET='/mnt/us/documents/${scriptletName}'
    MARKER_STATE=
    if [ -L "''${MARKER}" ]; then
      echo 'owned ${id} marker has an invalid state' >&2
      exit 1
    fi
    if [ -L '${mesquiteDirectory}' ]; then
      echo 'existing ${appId} installation is not owned by this package' >&2
      exit 1
    fi
    if { [ -e '${mesquiteDirectory}' ] || [ -L '${mesquiteDirectory}' ]; } && [ ! -f "''${MARKER}" ]; then
      echo 'existing ${appId} installation is not owned by this package' >&2
      exit 1
    fi
    if [ -f "''${MARKER}" ]; then
      MARKER_STATE="$(cat "''${MARKER}")"
    fi
    if [ -n "''${MARKER_STATE}" ]; then
      case "''${MARKER_STATE}" in
        active|handoff|retained) ;;
        *)
          echo 'owned ${id} marker has an invalid state' >&2
          exit 1
          ;;
      esac
    fi
    ${if documents == null then "" else ''
      DOCUMENTS_MARKER='${documents.directory}/.kpm-${id}'
      DOCUMENTS_MARKER_STATE=
      if [ -L "''${DOCUMENTS_MARKER}" ]; then
        echo 'owned ${id} Documents marker has an invalid state' >&2
        exit 1
      fi
      if [ -L '${documents.directory}' ]; then
        echo 'existing ${id} Documents tree is not owned by this package' >&2
        exit 1
      fi
      if { [ -e '${documents.directory}' ] || [ -L '${documents.directory}' ]; } && [ ! -f "''${DOCUMENTS_MARKER}" ]; then
        echo 'existing ${id} Documents tree is not owned by this package' >&2
        exit 1
      fi
      if [ -f "''${DOCUMENTS_MARKER}" ]; then
        DOCUMENTS_MARKER_STATE="$(cat "''${DOCUMENTS_MARKER}")"
      fi
      if [ -n "''${DOCUMENTS_MARKER_STATE}" ]; then
        case "''${DOCUMENTS_MARKER_STATE}" in
          active|handoff|retained) ;;
          *)
            echo 'owned ${id} Documents marker has an invalid state' >&2
            exit 1
            ;;
        esac
      fi
    ''}
    ${uninstallPrelude}
    if [ "''${1:-}" = upgrade ]; then
      if [ -f "''${SCRIPTLET}" ] && [ ! -L "''${SCRIPTLET}" ] && cmp -s 'scriptlets/${scriptletName}' "''${SCRIPTLET}"; then
        rm -f "''${SCRIPTLET}"
      fi
      if [ -f "''${MARKER}" ]; then
        printf '%s' handoff > "''${MARKER}"
      fi
      ${if documents == null then "" else ''
        if [ -f "''${DOCUMENTS_MARKER}" ]; then
          printf '%s' handoff > "''${DOCUMENTS_MARKER}"
        fi
      ''}
      exit 0
    fi
    if [ ! -f "''${MARKER}" ]; then
      exit 0
    fi
    if [ "''${MARKER_STATE}" = handoff ]; then
      exit 0
    fi
    if [ -f "''${SCRIPTLET}" ] && [ ! -L "''${SCRIPTLET}" ] && cmp -s 'scriptlets/${scriptletName}' "''${SCRIPTLET}"; then
      rm -f "''${SCRIPTLET}"
    fi
    ${if retainedPayloadPaths == [ ] then ''
      ${if documents == null || documentsRetainedPaths == [ ] then ''
        sqlite3 /var/local/appreg.db <<'SQL'
        DELETE FROM properties WHERE handlerId = '${appId}';
        DELETE FROM handlerIds WHERE handlerId = '${appId}';
        SQL
        rm -rf '${mesquiteDirectory}'
        ${if documents == null then "" else "rm -rf '${documents.directory}'"}
      '' else ''
        if [ -d '${documents.directory}' ]; then
          DOCUMENTS_MARKER='${documents.directory}/.kpm-${id}'
          DOCUMENTS_STAGING_DIRECTORY='${documentsParent}/.kpm-${id}-documents-retained-''${$}'
          DOCUMENTS_BACKUP_DIRECTORY='${documentsParent}/.kpm-${id}-documents-remove-''${$}'
          cleanup() {
            rm -rf "''${DOCUMENTS_STAGING_DIRECTORY}"
            if [ -e "''${DOCUMENTS_BACKUP_DIRECTORY}" ]; then
              rm -rf '${documents.directory}'
              mv "''${DOCUMENTS_BACKUP_DIRECTORY}" '${documents.directory}'
            fi
          }
          trap cleanup EXIT HUP INT TERM
          mv '${documents.directory}' "''${DOCUMENTS_BACKUP_DIRECTORY}"
          mkdir "''${DOCUMENTS_STAGING_DIRECTORY}"
          DOCUMENTS_RETAINED_SOURCE="''${DOCUMENTS_BACKUP_DIRECTORY}"
          DOCUMENTS_RETAINED_DESTINATION="''${DOCUMENTS_STAGING_DIRECTORY}"
          ${documentsRetainedPayloadCopy}
          printf '%s' retained > "''${DOCUMENTS_STAGING_DIRECTORY}/.kpm-${id}"
          mv "''${DOCUMENTS_STAGING_DIRECTORY}" '${documents.directory}'
          sqlite3 /var/local/appreg.db "DELETE FROM properties WHERE handlerId = '${appId}'; DELETE FROM handlerIds WHERE handlerId = '${appId}';"
          rm -rf '${mesquiteDirectory}'
          rm -rf "''${DOCUMENTS_BACKUP_DIRECTORY}"
          trap - EXIT HUP INT TERM
        else
          sqlite3 /var/local/appreg.db "DELETE FROM properties WHERE handlerId = '${appId}'; DELETE FROM handlerIds WHERE handlerId = '${appId}';"
          rm -rf '${mesquiteDirectory}'
        fi
      ''}
    '' else ''
      STAGING_DIRECTORY='${mesquiteParent}/.kpm-${id}-retained-''${$}'
      BACKUP_DIRECTORY='${mesquiteParent}/.kpm-${id}-remove-''${$}'
      cleanup() {
        rm -rf "''${STAGING_DIRECTORY}"
        if [ -e "''${BACKUP_DIRECTORY}" ]; then
          rm -rf '${mesquiteDirectory}'
          mv "''${BACKUP_DIRECTORY}" '${mesquiteDirectory}'
        fi
      }
      trap cleanup EXIT HUP INT TERM
      mv '${mesquiteDirectory}' "''${BACKUP_DIRECTORY}"
      mkdir "''${STAGING_DIRECTORY}"
      RETAINED_SOURCE="''${BACKUP_DIRECTORY}"
      RETAINED_DESTINATION="''${STAGING_DIRECTORY}"
      ${retainedPayloadCopy}
      printf '%s' retained > "''${STAGING_DIRECTORY}/.kpm-${id}"
      mv "''${STAGING_DIRECTORY}" '${mesquiteDirectory}'
      sqlite3 /var/local/appreg.db <<'SQL'
      DELETE FROM properties WHERE handlerId = '${appId}';
      DELETE FROM handlerIds WHERE handlerId = '${appId}';
      SQL
      rm -rf "''${BACKUP_DIRECTORY}"
      trap - EXIT HUP INT TERM
    ''}
    rm -f .kpm-install-success
  '';
  launchScript = builtins.toFile "${id}-launch.sh" ''
    set -eu
    ${launchPrelude}
    nohup lipc-set-prop com.lab126.appmgrd start 'app://${appId}' >/dev/null 2>&1 &
  '';
}).overrideAttrs (previous: {
  passthru = previous.passthru // {
    waf = {
      inherit documents installPrelude legacyPaths lifecycleFailureFixture mesquiteDirectory payloadDirectory retainedPayloadPaths scriptletName uninstallPrelude;
    };
  };
})
