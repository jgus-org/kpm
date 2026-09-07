set -eu

INSTALL_SCRIPT=${1}
UNINSTALL_SCRIPT=${2}
RUN_SCRIPT=${3}
LICENSE=${4}
FIXTURE_DIRECTORY=${TMPDIR}/alpinelinux-lifecycle
EXTRACTED_DIRECTORY=${FIXTURE_DIRECTORY}/extracted
MOCK_DIRECTORY=${FIXTURE_DIRECTORY}/bin
APPLICATION_DIRECTORY=${FIXTURE_DIRECTORY}/mnt/us/extensions/alpinelinux
IMAGE=${FIXTURE_DIRECTORY}/mnt/us/alpine.ext3
LOG=${FIXTURE_DIRECTORY}/mnt/us/alpine.log
GUI_SCRIPTLET="${FIXTURE_DIRECTORY}/mnt/us/documents/Alpine Linux.sh"
SHELL_SCRIPTLET="${FIXTURE_DIRECTORY}/mnt/us/documents/Alpine Linux Shell.sh"
MOUNTED=${FIXTURE_DIRECTORY}/mounted

mkdir -p "${EXTRACTED_DIRECTORY}/payload/alpinelinux" \
  "${EXTRACTED_DIRECTORY}/scriptlets" "${MOCK_DIRECTORY}" \
  "${FIXTURE_DIRECTORY}/mnt/us/extensions" "${FIXTURE_DIRECTORY}/mnt/us/documents"
cp "${RUN_SCRIPT}" "${EXTRACTED_DIRECTORY}/payload/alpinelinux/run.sh"
cp "${LICENSE}" "${EXTRACTED_DIRECTORY}/payload/alpinelinux/LICENSE"
printf '%s\n' \
  '# Name: Alpine Linux' \
  '# Author: Simon Schumann' \
  '# DontUseFBInk' \
  'exec /var/local/kmc/bin/kpm launch alpinelinux gui' \
  >"${EXTRACTED_DIRECTORY}/scriptlets/Alpine Linux.sh"
printf '%s\n' \
  '# Name: Alpine Linux Shell' \
  '# Author: Simon Schumann' \
  '# DontUseFBInk' \
  'exec /var/local/kmc/bin/kpm launch alpinelinux shell' \
  >"${EXTRACTED_DIRECTORY}/scriptlets/Alpine Linux Shell.sh"
printf '%s\n' LICENSE run.sh >"${EXTRACTED_DIRECTORY}/native-files"
: >"${EXTRACTED_DIRECTORY}/native-directories"
sed "s#/mnt/us#${FIXTURE_DIRECTORY}/mnt/us#g" "${INSTALL_SCRIPT}" >"${EXTRACTED_DIRECTORY}/install.sh"
sed "s#/mnt/us#${FIXTURE_DIRECTORY}/mnt/us#g" "${UNINSTALL_SCRIPT}" >"${EXTRACTED_DIRECTORY}/uninstall.sh"

printf '%s\n' \
  '#!/bin/sh' \
  'set -u' \
  'case "${0##*/}" in' \
  '  mount)' \
  '    if [ -f "${ALPINE_TEST_MOUNTED}" ]; then printf '\''%s\n'\'' '\''/dev/loop7 on /tmp/alpinelinux type ext3 (rw)'\''; fi' \
  '    ;;' \
  '  losetup)' \
  '    if [ "${1:-}" = -a ] && [ -f "${ALPINE_TEST_MOUNTED}" ]; then printf '\''%s\n'\'' "/dev/loop7: (${ALPINE_TEST_IMAGE})"; fi' \
  '    ;;' \
  'esac' \
  >"${MOCK_DIRECTORY}/mock"
chmod 755 "${MOCK_DIRECTORY}/mock"
ln -s mock "${MOCK_DIRECTORY}/mount"
ln -s mock "${MOCK_DIRECTORY}/losetup"

run_hook() {
  HOOK=${1}
  shift
  (
    cd "${EXTRACTED_DIRECTORY}"
    env \
      PATH="${MOCK_DIRECTORY}:${PATH}" \
      ALPINE_TEST_MOUNTED="${MOUNTED}" \
      ALPINE_TEST_IMAGE="${IMAGE}" \
      sh "./${HOOK}" "${@}"
  )
}

run_hook install.sh
test -f "${APPLICATION_DIRECTORY}/.kpm-alpinelinux"
test -f "${GUI_SCRIPTLET}"
test -f "${SHELL_SCRIPTLET}"
printf '%s' user-image >"${IMAGE}"
printf '%s' user-log >"${LOG}"

touch "${MOUNTED}"
if run_hook uninstall.sh upgrade; then
  exit 1
fi
test -f "${APPLICATION_DIRECTORY}/run.sh"
test -f "${GUI_SCRIPTLET}"
test -f "${SHELL_SCRIPTLET}"
test "$(cat "${IMAGE}")" = user-image
test "$(cat "${LOG}")" = user-log

rm "${MOUNTED}"
run_hook uninstall.sh upgrade
test "$(cat "${APPLICATION_DIRECTORY}/.kpm-alpinelinux")" = retained
test ! -e "${GUI_SCRIPTLET}"
test ! -e "${SHELL_SCRIPTLET}"

touch "${MOUNTED}"
if run_hook install.sh upgrade; then
  exit 1
fi
test -f "${EXTRACTED_DIRECTORY}/.kpm-install-success.pending"
test "$(cat "${APPLICATION_DIRECTORY}/.kpm-alpinelinux")" = retained
run_hook uninstall.sh
test ! -e "${EXTRACTED_DIRECTORY}/.kpm-install-success.pending"
test "$(cat "${APPLICATION_DIRECTORY}/.kpm-alpinelinux")" = retained

rm "${MOUNTED}"
run_hook install.sh upgrade
test -f "${APPLICATION_DIRECTORY}/run.sh"
test -f "${GUI_SCRIPTLET}"
test -f "${SHELL_SCRIPTLET}"

touch "${MOUNTED}"
if run_hook uninstall.sh; then
  exit 1
fi
test -f "${APPLICATION_DIRECTORY}/run.sh"
test -f "${GUI_SCRIPTLET}"
test -f "${SHELL_SCRIPTLET}"

rm "${MOUNTED}"
run_hook uninstall.sh
test ! -e "${APPLICATION_DIRECTORY}"
test ! -e "${GUI_SCRIPTLET}"
test ! -e "${SHELL_SCRIPTLET}"
test "$(cat "${IMAGE}")" = user-image
test "$(cat "${LOG}")" = user-log
