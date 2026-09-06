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
,
}:
assert (legacyPayloadDirectory == null) == (legacyFirmwareMaximum == null);
assert legacyFirmwareMaximum == null || builtins.length legacyFirmwareMaximum == 4;
assert scriptletIcon == null || (
  builtins.isString scriptletIcon.path
    && builtins.match "[a-z0-9.+-]+" scriptletIcon.mediaSubtype != null
);
let
  mesquiteParent = builtins.dirOf mesquiteDirectory;
  scriptletBody = writeTextFile {
    name = "${id}-scriptlet.sh";
    text = ''
      # DontUseFBInk
      exec /var/local/kmc/bin/kpm launch ${id}
    '';
  };
  legacyCollision = builtins.concatStringsSep " || " (map (path: "[ -e '${path}' ]") legacyPaths);
in
(mkKpackage {
  inherit id name author description version platforms src;
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
    MARKER='${mesquiteDirectory}/.kpm-${id}'
    SCRIPTLET='/mnt/us/documents/${scriptletName}'
    SCRIPTLET_STAGE='/mnt/us/documents/.kpm-${id}-scriptlet-$$'
    if [ ! -f "''${MARKER}" ] && { ${legacyCollision}; }; then
      echo 'a KindleForge ${id} deployment already exists' >&2
      exit 1
    fi
    if [ -e "''${SCRIPTLET}" ] && ! cmp -s 'scriptlets/${scriptletName}' "''${SCRIPTLET}"; then
      echo 'existing ${scriptletName} is not owned by this package' >&2
      exit 1
    fi
    HANDLER_COUNT="$(sqlite3 /var/local/appreg.db "SELECT COUNT(*) FROM handlerIds WHERE handlerId = '${appId}';")"
    if [ ! -f "''${MARKER}" ] && { [ -e '${mesquiteDirectory}' ] || [ "''${HANDLER_COUNT}" != 0 ]; }; then
      echo 'existing ${appId} installation is not owned by this package' >&2
      exit 1
    fi
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
    STAGING_DIRECTORY='${mesquiteParent}/.kpm-${id}-stage-$$'
    cleanup() {
      rm -rf "''${STAGING_DIRECTORY}"
      rm -f "''${SCRIPTLET_STAGE}"
    }
    trap cleanup EXIT HUP INT TERM
    mkdir -p /mnt/us/documents
    cp 'scriptlets/${scriptletName}' "''${SCRIPTLET_STAGE}"
    mkdir -p '${mesquiteParent}'
    mkdir "''${STAGING_DIRECTORY}"
    cp -R "''${PAYLOAD_DIRECTORY}/." "''${STAGING_DIRECTORY}/"
    : > "''${STAGING_DIRECTORY}/.kpm-${id}"
    rm -rf '${mesquiteDirectory}'
    mv "''${STAGING_DIRECTORY}" '${mesquiteDirectory}'
    sqlite3 /var/local/appreg.db <<'SQL'
    INSERT OR IGNORE INTO handlerIds(handlerId) VALUES('${appId}');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'lipcId', '${appId}');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'command', '/usr/bin/mesquite -l ${appId} -c file://${mesquiteDirectory}/');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'supportedOrientation', 'U');
    SQL
    mv -f "''${SCRIPTLET_STAGE}" "''${SCRIPTLET}"
    trap - EXIT HUP INT TERM
  '';
  uninstallScript = builtins.toFile "${id}-uninstall.sh" ''
    set -eu
    MARKER='${mesquiteDirectory}/.kpm-${id}'
    SCRIPTLET='/mnt/us/documents/${scriptletName}'
    if [ -f "''${SCRIPTLET}" ] && cmp -s 'scriptlets/${scriptletName}' "''${SCRIPTLET}"; then
      rm -f "''${SCRIPTLET}"
    fi
    if [ "''${1:-}" = upgrade ]; then
      exit 0
    fi
    if [ ! -f "''${MARKER}" ]; then
      exit 0
    fi
    sqlite3 /var/local/appreg.db <<'SQL'
    DELETE FROM properties WHERE handlerId = '${appId}';
    DELETE FROM handlerIds WHERE handlerId = '${appId}';
    SQL
    rm -rf '${mesquiteDirectory}'
  '';
  launchScript = builtins.toFile "${id}-launch.sh" ''
    set -eu
    nohup lipc-set-prop com.lab126.appmgrd start 'app://${appId}' >/dev/null 2>&1 &
  '';
}).overrideAttrs (previous: {
  passthru = previous.passthru // {
    waf = {
      inherit legacyPaths mesquiteDirectory scriptletName;
    };
  };
})
