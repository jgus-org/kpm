{ lib, pkgs }:
{ id
, displayName
, destination
, payloadPath
, preservedPaths ? [ ]
, scriptlets ? [ ]
, installPreflight ? ""
, uninstallPreflight ? ""
, prepareStaging ? ""
,
}:
let
  ownerFile = "${destination}/.kpm-${id}";
  transactionPrefix = "${dirOf destination}/.kpm-${id}-";
  preservePath = path: ''
    if [ -e "''${APPLICATION_DIRECTORY}/${path}" ] || [ -L "''${APPLICATION_DIRECTORY}/${path}" ]; then
      rm -rf "''${STAGING_DIRECTORY}/${path}"
      mkdir -p "$(dirname "''${STAGING_DIRECTORY}/${path}")"
      cp -a "''${APPLICATION_DIRECTORY}/${path}" "''${STAGING_DIRECTORY}/${path}"
    fi
  '';
  rejectScriptlet = scriptlet: ''
    if { [ -e "${scriptlet.destination}" ] || [ -L "${scriptlet.destination}" ]; } && ! cmp -s "${scriptlet.source}" "${scriptlet.destination}"; then
      echo ${lib.escapeShellArg "existing ${baseNameOf scriptlet.destination} is not owned by this package"} >&2
      exit 1
    fi
  '';
  stageScriptlet = scriptlet: ''
    mkdir -p "''${TRANSACTION_DIRECTORY}/scriptlets"
    cp "${scriptlet.source}" "''${TRANSACTION_DIRECTORY}/scriptlets/${baseNameOf scriptlet.destination}"
  '';
  installScriptlet = scriptlet: ''
    mkdir -p ${lib.escapeShellArg (dirOf scriptlet.destination)}
    if [ -e "${scriptlet.destination}" ]; then
      mv "${scriptlet.destination}" "''${TRANSACTION_DIRECTORY}/old-scriptlets/${baseNameOf scriptlet.destination}"
    fi
    mv "''${TRANSACTION_DIRECTORY}/scriptlets/${baseNameOf scriptlet.destination}" "${scriptlet.destination}"
  '';
  restoreScriptlet = scriptlet: ''
    if [ -e "''${TRANSACTION_DIRECTORY}/old-scriptlets/${baseNameOf scriptlet.destination}" ] || [ -L "''${TRANSACTION_DIRECTORY}/old-scriptlets/${baseNameOf scriptlet.destination}" ]; then
      rm -f "${scriptlet.destination}"
      mv "''${TRANSACTION_DIRECTORY}/old-scriptlets/${baseNameOf scriptlet.destination}" "${scriptlet.destination}"
    elif [ -e "''${TRANSACTION_DIRECTORY}/scriptlets-installed" ]; then
      rm -f "${scriptlet.destination}"
    fi
  '';
  removeScriptlet = scriptlet: ''
    if [ -f "${scriptlet.destination}" ] && cmp -s "${scriptlet.source}" "${scriptlet.destination}"; then
      rm -f "${scriptlet.destination}"
    fi
  '';
  preservedCases = lib.concatMapStringsSep " | "
    (path: "${lib.escapeShellArg path} | ${lib.escapeShellArg "${path}/"}*")
    preservedPaths;
  installScript = pkgs.writeTextFile {
    name = "${id}-install.sh";
    text = ''
      set -eu

      APPLICATION_DIRECTORY=${lib.escapeShellArg destination}
      OWNER_FILE=${lib.escapeShellArg ownerFile}
      TRANSACTION_DIRECTORY=${lib.escapeShellArg transactionPrefix}"''${$}"
      STAGING_DIRECTORY="''${TRANSACTION_DIRECTORY}/new"
      BACKUP_DIRECTORY="''${TRANSACTION_DIRECTORY}/old"
      UNMANAGED_DIRECTORY="''${TRANSACTION_DIRECTORY}/unmanaged"
      OWNED=0
      BACKED_UP=0
      INSTALLED=0
      COMMITTED=0

      : > .kpm-install-success.pending

      ${installPreflight}

      cleanup() {
        trap - EXIT HUP INT TERM
        if [ "''${COMMITTED}" -eq 1 ]; then
          rm -rf "''${TRANSACTION_DIRECTORY}"
          return
        fi
        if [ "''${INSTALLED}" -eq 1 ]; then
          rm -rf "''${APPLICATION_DIRECTORY}"
        fi
        if [ "''${BACKED_UP}" -eq 1 ] && { [ -e "''${BACKUP_DIRECTORY}" ] || [ -L "''${BACKUP_DIRECTORY}" ]; }; then
          mv "''${BACKUP_DIRECTORY}" "''${APPLICATION_DIRECTORY}"
        fi
        ${lib.concatMapStrings restoreScriptlet scriptlets}
        rm -rf "''${TRANSACTION_DIRECTORY}"
      }

      if [ -f "''${OWNER_FILE}" ] && { [ "$(cat "''${OWNER_FILE}")" = installed ] || [ "$(cat "''${OWNER_FILE}")" = retained ]; }; then
        OWNED=1
      elif [ -e "''${APPLICATION_DIRECTORY}" ] || [ -L "''${APPLICATION_DIRECTORY}" ]; then
        echo ${lib.escapeShellArg "${displayName} files already exist"} >&2
        exit 1
      fi

      ${lib.concatMapStrings rejectScriptlet scriptlets}

      if [ "''${1:-}" = upgrade ] && [ "''${OWNED}" -eq 0 ]; then
        echo ${lib.escapeShellArg "${displayName} upgrade handoff is absent"} >&2
        exit 1
      fi

      if ! mkdir "''${TRANSACTION_DIRECTORY}"; then
        echo ${lib.escapeShellArg "${displayName} transaction path already exists"} >&2
        exit 1
      fi

      mkdir "''${STAGING_DIRECTORY}" "''${UNMANAGED_DIRECTORY}" "''${TRANSACTION_DIRECTORY}/old-scriptlets"
      trap cleanup EXIT
      trap 'exit 1' HUP INT TERM
      cp -a ${lib.escapeShellArg payloadPath}/. "''${STAGING_DIRECTORY}/"
      ${prepareStaging}
      if [ "''${OWNED}" -eq 1 ]; then
        cp -a "''${APPLICATION_DIRECTORY}/." "''${UNMANAGED_DIRECTORY}/"
        rm -f "''${UNMANAGED_DIRECTORY}/.kpm-${id}"
        ${lib.concatMapStrings preservePath preservedPaths}
        ${lib.concatMapStrings (path: ''rm -rf "''${UNMANAGED_DIRECTORY}/${path}"
        '') preservedPaths}
      fi

      merge_unmanaged() (
        SOURCE_DIRECTORY="''${1}"
        TARGET_DIRECTORY="''${2}"
        for SOURCE_PATH in "''${SOURCE_DIRECTORY}"/* "''${SOURCE_DIRECTORY}"/.[!.]* "''${SOURCE_DIRECTORY}"/..?*; do
          if [ ! -e "''${SOURCE_PATH}" ] && [ ! -L "''${SOURCE_PATH}" ]; then
            continue
          fi
          NAME="''${SOURCE_PATH##*/}"
          TARGET_PATH="''${TARGET_DIRECTORY}/''${NAME}"
          if [ -d "''${SOURCE_PATH}" ] && [ ! -L "''${SOURCE_PATH}" ]; then
            if [ ! -e "''${TARGET_PATH}" ] && [ ! -L "''${TARGET_PATH}" ]; then
              mv "''${SOURCE_PATH}" "''${TARGET_PATH}"
            elif [ -d "''${TARGET_PATH}" ] && [ ! -L "''${TARGET_PATH}" ]; then
              merge_unmanaged "''${SOURCE_PATH}" "''${TARGET_PATH}"
              if [ -d "''${SOURCE_PATH}" ]; then
                rmdir "''${SOURCE_PATH}"
              fi
            else
              echo ${lib.escapeShellArg "${displayName} retained data conflicts with the new payload"} >&2
              return 1
            fi
          elif [ -e "''${TARGET_PATH}" ] || [ -L "''${TARGET_PATH}" ]; then
            echo ${lib.escapeShellArg "${displayName} retained data conflicts with the new payload"} >&2
            return 1
          else
            mv "''${SOURCE_PATH}" "''${TARGET_PATH}"
          fi
        done
      )
      merge_unmanaged "''${UNMANAGED_DIRECTORY}" "''${STAGING_DIRECTORY}"
      printf '%s' installed >"''${STAGING_DIRECTORY}/.kpm-${id}"
      ${lib.concatMapStrings stageScriptlet scriptlets}

      if [ "''${OWNED}" -eq 1 ]; then
        BACKED_UP=1
        mv "''${APPLICATION_DIRECTORY}" "''${BACKUP_DIRECTORY}"
      fi
      mkdir -p ${lib.escapeShellArg (dirOf destination)}
      mv "''${STAGING_DIRECTORY}" "''${APPLICATION_DIRECTORY}"
      INSTALLED=1
      touch "''${TRANSACTION_DIRECTORY}/scriptlets-installed"
      ${lib.concatMapStrings installScriptlet scriptlets}
      mv .kpm-install-success.pending .kpm-install-success
      COMMITTED=1
      BACKED_UP=0
      INSTALLED=0
      rm -rf "''${TRANSACTION_DIRECTORY}"
      trap - EXIT HUP INT TERM
    '';
    executable = true;
  };
  uninstallScript = pkgs.writeTextFile {
    name = "${id}-uninstall.sh";
    text = ''
      set -eu

      APPLICATION_DIRECTORY=${lib.escapeShellArg destination}
      OWNER_FILE=${lib.escapeShellArg ownerFile}

      if [ ! -f .kpm-install-success ]; then
        rm -f .kpm-install-success.pending
        exit 0
      fi

      ${uninstallPreflight}

      if [ ! -f "''${OWNER_FILE}" ] || { [ "$(cat "''${OWNER_FILE}")" != installed ] && [ "$(cat "''${OWNER_FILE}")" != retained ]; }; then
        exit 0
      fi

      has_symlink_parent() {
        PARENT_PATH="''${1}"
        CHECKED_PATH="''${APPLICATION_DIRECTORY}"
        while [ "''${PARENT_PATH#*/}" != "''${PARENT_PATH}" ]; do
          CHECKED_PATH="''${CHECKED_PATH}/''${PARENT_PATH%%/*}"
          if [ -L "''${CHECKED_PATH}" ]; then
            return 0
          fi
          PARENT_PATH="''${PARENT_PATH#*/}"
        done
        return 1
      }

      while IFS= read -r PATHNAME; do
        if ! has_symlink_parent "''${PATHNAME}"; then
          rm -f "''${APPLICATION_DIRECTORY}/''${PATHNAME}"
        fi
      done < native-files
      while IFS= read -r PATHNAME; do
        if ! has_symlink_parent "''${PATHNAME}"; then
          rmdir "''${APPLICATION_DIRECTORY}/''${PATHNAME}" 2>/dev/null || true
        fi
      done < native-directories
      ${lib.concatMapStrings removeScriptlet scriptlets}
      rm -f "''${OWNER_FILE}"
      rm -f .kpm-install-success
      if [ "''${1:-}" = upgrade ]; then
        mkdir -p "''${APPLICATION_DIRECTORY}"
        printf '%s' retained >"''${OWNER_FILE}"
        exit 0
      fi
      if ! rmdir "''${APPLICATION_DIRECTORY}" 2>/dev/null; then
        printf '%s' retained >"''${OWNER_FILE}"
      fi
    '';
    executable = true;
  };
in
{
  inherit installScript uninstallScript;
  buildInventory = ''
    (cd ${lib.escapeShellArg payloadPath} && ${lib.getExe pkgs.findutils} . \( -type f -o -type l \) -printf '%P\n' | ${lib.getExe' pkgs.coreutils "sort"}) > native-files-all
    while IFS= read -r PATHNAME; do
      case "''${PATHNAME}" in
        ${lib.optionalString (preservedPaths != [ ]) "${preservedCases}) ;;"}
        *) printf '%s\n' "''${PATHNAME}" ;;
      esac
    done < native-files-all > native-files
    rm native-files-all
    (cd ${lib.escapeShellArg payloadPath} && ${lib.getExe pkgs.findutils} . -mindepth 1 -type d -printf '%P\n' | ${lib.getExe' pkgs.coreutils "sort"} -r) > native-directories
  '';
  passthru = {
    inherit destination payloadPath preservedPaths scriptlets installPreflight uninstallPreflight prepareStaging;
    marker = ownerFile;
  };
}
