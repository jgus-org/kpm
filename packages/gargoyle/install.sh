#!/bin/sh

set -eu

APPLICATION_DIRECTORY=/mnt/us/extensions/gargoyle
OWNER_FILE=${APPLICATION_DIRECTORY}/.kpm-owner
STAGING_DIRECTORY=/mnt/us/extensions/.kpm-gargoyle-new-${$}
BACKUP_DIRECTORY=/mnt/us/extensions/.kpm-gargoyle-old-${$}
OWNED=0
BACKED_UP=0
INSTALLED=0

cleanup() {
  trap - EXIT HUP INT TERM
  if [ "${INSTALLED}" -eq 1 ]; then
    rm -rf "${APPLICATION_DIRECTORY}"
  fi
  if [ "${BACKED_UP}" -eq 1 ]; then
    if [ -e "${BACKUP_DIRECTORY}" ]; then
      mv "${BACKUP_DIRECTORY}" "${APPLICATION_DIRECTORY}"
      printf '%s' retained >"${OWNER_FILE}"
    fi
  fi
  rm -rf "${STAGING_DIRECTORY}" "${BACKUP_DIRECTORY}"
}

trap cleanup EXIT HUP INT TERM

if [ -f "${OWNER_FILE}" ] && { [ "$(cat "${OWNER_FILE}")" = installed ] || [ "$(cat "${OWNER_FILE}")" = retained ]; }; then
  OWNED=1
elif [ -e "${APPLICATION_DIRECTORY}" ]; then
  echo "Gargoyle files already exist" >&2
  exit 1
fi

if [ "${1:-}" = upgrade ] && [ "${OWNED}" -eq 0 ]; then
  echo "Gargoyle upgrade handoff is absent" >&2
  exit 1
fi

if [ -e "${STAGING_DIRECTORY}" ] || [ -e "${BACKUP_DIRECTORY}" ]; then
  echo "Gargoyle transaction path already exists" >&2
  exit 1
fi

mkdir -p "${STAGING_DIRECTORY}"
cp -a payload/gargoyle/. "${STAGING_DIRECTORY}/"

if [ "${OWNED}" -eq 1 ]; then
  if [ -f "${APPLICATION_DIRECTORY}/dist/garglk.ini" ]; then
    cp -a "${APPLICATION_DIRECTORY}/dist/garglk.ini" "${STAGING_DIRECTORY}/dist/garglk.ini"
  fi
  if [ -d "${APPLICATION_DIRECTORY}/saved_games" ]; then
    rm -rf "${STAGING_DIRECTORY}/saved_games"
    cp -a "${APPLICATION_DIRECTORY}/saved_games" "${STAGING_DIRECTORY}/saved_games"
  fi
  if [ -d "${APPLICATION_DIRECTORY}/games" ]; then
    rm -rf "${STAGING_DIRECTORY}/games"
    cp -a "${APPLICATION_DIRECTORY}/games" "${STAGING_DIRECTORY}/games"
  fi
  BACKED_UP=1
  mv "${APPLICATION_DIRECTORY}" "${BACKUP_DIRECTORY}"
fi

printf '%s' installed >"${STAGING_DIRECTORY}/.kpm-owner"
mv "${STAGING_DIRECTORY}" "${APPLICATION_DIRECTORY}"
INSTALLED=1
rm -rf "${BACKUP_DIRECTORY}"
BACKED_UP=0
INSTALLED=0
trap - EXIT HUP INT TERM
