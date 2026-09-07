set -eu

INSTALL_SCRIPT=${1}
UNINSTALL_SCRIPT=${2}
FIXTURE_DIRECTORY="$(mktemp -d)"
MOCK_DIRECTORY=${FIXTURE_DIRECTORY}/bin
SCRIPTLET=${FIXTURE_DIRECTORY}/mnt/us/documents/toggle-ads.sh

trap 'rm -rf "${FIXTURE_DIRECTORY}"' EXIT

mkdir -p "${MOCK_DIRECTORY}" "${FIXTURE_DIRECTORY}/package/scriptlets" "${FIXTURE_DIRECTORY}/mnt/us/documents"
printf '%s\n' 'exec /var/local/kmc/bin/kpm launch toggleads' >"${FIXTURE_DIRECTORY}/package/scriptlets/toggle-ads.sh"
cp "${FIXTURE_DIRECTORY}/package/scriptlets/toggle-ads.sh" "${SCRIPTLET}"
printf '%s\n' '#!/bin/sh' 'exit 1' >"${MOCK_DIRECTORY}/cp"
chmod 755 "${MOCK_DIRECTORY}/cp"
sed "s#/mnt/us#${FIXTURE_DIRECTORY}/mnt/us#g" "${INSTALL_SCRIPT}" >"${FIXTURE_DIRECTORY}/package/install.sh"
sed "s#/mnt/us#${FIXTURE_DIRECTORY}/mnt/us#g" "${UNINSTALL_SCRIPT}" >"${FIXTURE_DIRECTORY}/package/uninstall.sh"
(cd "${FIXTURE_DIRECTORY}/package" && PATH="${MOCK_DIRECTORY}:${PATH}" sh install.sh)
test "$(cat "${SCRIPTLET}")" = 'exec /var/local/kmc/bin/kpm launch toggleads'
printf '%s\n' 'exec /var/local/kmc/bin/kpm launch toggleads' >"${FIXTURE_DIRECTORY}/foreign.sh"
rm "${SCRIPTLET}"
ln -s "${FIXTURE_DIRECTORY}/foreign.sh" "${SCRIPTLET}"
if (cd "${FIXTURE_DIRECTORY}/package" && sh install.sh); then
  exit 1
fi
(cd "${FIXTURE_DIRECTORY}/package" && sh uninstall.sh)
test -L "${SCRIPTLET}"
test "$(cat "${SCRIPTLET}")" = 'exec /var/local/kmc/bin/kpm launch toggleads'
