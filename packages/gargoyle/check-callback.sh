set -eu

INSTALL_SCRIPT=${1}
UNINSTALL_SCRIPT=${2}
FIXTURE_DIRECTORY="$(mktemp -d)"
OLD_DIRECTORY=${FIXTURE_DIRECTORY}/old
NEW_DIRECTORY=${FIXTURE_DIRECTORY}/new
APPLICATION_DIRECTORY=${FIXTURE_DIRECTORY}/mnt/us/extensions/gargoyle
SCRIPTLET=${FIXTURE_DIRECTORY}/mnt/us/documents/Gargoyle.sh

trap 'rm -rf "${FIXTURE_DIRECTORY}"' EXIT

prepare_package() {
  PACKAGE_DIRECTORY=${1}
  mkdir -p "${PACKAGE_DIRECTORY}/payload/gargoyle/dist" "${PACKAGE_DIRECTORY}/scriptlets"
  printf '%s' application >"${PACKAGE_DIRECTORY}/payload/gargoyle/dist/gargoyle"
  printf '%s\n' 'exec /var/local/kmc/bin/kpm launch gargoyle' >"${PACKAGE_DIRECTORY}/scriptlets/Gargoyle.sh"
  sed "s#/mnt/us#${FIXTURE_DIRECTORY}/mnt/us#g" "${INSTALL_SCRIPT}" >"${PACKAGE_DIRECTORY}/install.sh"
  sed "s#/mnt/us#${FIXTURE_DIRECTORY}/mnt/us#g" "${UNINSTALL_SCRIPT}" >"${PACKAGE_DIRECTORY}/uninstall.sh"
}

prepare_package "${OLD_DIRECTORY}"
prepare_package "${NEW_DIRECTORY}"

(cd "${OLD_DIRECTORY}" && sh install.sh)
mkdir -p "${APPLICATION_DIRECTORY}/games"
printf '%s' save >"${APPLICATION_DIRECTORY}/games/story.sav"
printf '%s' foreign >"${SCRIPTLET}"

if (cd "${NEW_DIRECTORY}" && sh install.sh upgrade); then
  exit 1
fi
test -f "${NEW_DIRECTORY}/.kpm-install-success.pending"
(cd "${NEW_DIRECTORY}" && sh uninstall.sh)
test ! -e "${NEW_DIRECTORY}/.kpm-install-success.pending"
test "$(cat "${APPLICATION_DIRECTORY}/.kpm-owner")" = installed
test "$(cat "${APPLICATION_DIRECTORY}/games/story.sav")" = save
test "$(cat "${SCRIPTLET}")" = foreign
