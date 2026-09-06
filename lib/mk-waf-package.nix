{ mkKpackage }:
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
, legacyPayloadDirectory ? null
,
}:
let
  mesquiteParent = builtins.dirOf mesquiteDirectory;
  legacyPaths = {
    kpomo = [
      "/mnt/us/documents/kpomo"
      "/mnt/us/documents/kpomo.sh"
    ];
    kreate = [ "/mnt/us/documents/kreate" ];
    kships = [
      "/mnt/us/documents/KShips"
      "/mnt/us/documents/KShips.sh"
    ];
    kwordle = [
      "/mnt/us/documents/kwordle"
      "/mnt/us/documents/kwordle.sh"
    ];
  }.${id};
  legacyCollision = builtins.concatStringsSep " || " (map (path: "[ -e '${path}' ]") legacyPaths);
in
mkKpackage {
  inherit id name author description version platforms src buildPayload;
  installScript = builtins.toFile "${id}-install.sh" ''
    set -eu
    MARKER='${mesquiteDirectory}/.kpm-${id}'
    if ${legacyCollision}; then
      echo 'a KindleForge ${id} deployment already exists' >&2
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
      if [ "''${FIRMWARE_MAJOR}" -lt 5 ] || \
        { [ "''${FIRMWARE_MAJOR}" -eq 5 ] && [ "''${FIRMWARE_MINOR}" -lt 6 ]; } || \
        { [ "''${FIRMWARE_MAJOR}" -eq 5 ] && [ "''${FIRMWARE_MINOR}" -eq 6 ] && [ "''${FIRMWARE_PATCH}" -lt 1 ]; } || \
        { [ "''${FIRMWARE_MAJOR}" -eq 5 ] && [ "''${FIRMWARE_MINOR}" -eq 6 ] && [ "''${FIRMWARE_PATCH}" -eq 1 ] && [ "''${FIRMWARE_BUILD}" -le 1 ]; }; then
        PAYLOAD_DIRECTORY='${legacyPayloadDirectory}'
      fi
    ''}
    STAGING_DIRECTORY='${mesquiteParent}/.kpm-${id}-stage-$$'
    cleanup() {
      rm -rf "''${STAGING_DIRECTORY}"
    }
    trap cleanup EXIT HUP INT TERM
    mkdir -p '${mesquiteParent}'
    mkdir "''${STAGING_DIRECTORY}"
    cp -R "''${PAYLOAD_DIRECTORY}/." "''${STAGING_DIRECTORY}/"
    : > "''${STAGING_DIRECTORY}/.kpm-${id}"
    rm -rf '${mesquiteDirectory}'
    mv "''${STAGING_DIRECTORY}" '${mesquiteDirectory}'
    trap - EXIT HUP INT TERM
    sqlite3 /var/local/appreg.db <<'SQL'
    INSERT OR IGNORE INTO handlerIds(handlerId) VALUES('${appId}');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'lipcId', '${appId}');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'command', '/usr/bin/mesquite -l ${appId} -c file://${mesquiteDirectory}/');
    INSERT OR REPLACE INTO properties(handlerId, name, value) VALUES('${appId}', 'supportedOrientation', 'U');
    SQL
  '';
  uninstallScript = builtins.toFile "${id}-uninstall.sh" ''
    set -eu
    MARKER='${mesquiteDirectory}/.kpm-${id}'
    if [ ! -f "''${MARKER}" ]; then
      exit 0
    fi
    if [ "''${1:-}" = upgrade ]; then
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
}
