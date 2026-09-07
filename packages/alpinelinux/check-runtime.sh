set -eu

RUN_SCRIPT=${1}
FIXTURE_DIRECTORY=${TMPDIR}/alpinelinux-runtime
MOCK_DIRECTORY=${FIXTURE_DIRECTORY}/bin
APPLICATION_DIRECTORY=${FIXTURE_DIRECTORY}/application
MOUNT_DIRECTORY=${FIXTURE_DIRECTORY}/mount
IMAGE=${FIXTURE_DIRECTORY}/alpine.ext3
ARCHIVE=${FIXTURE_DIRECTORY}/alpine.zip
LOG=${FIXTURE_DIRECTORY}/calls

reset_fixture() {
  rm -rf "${FIXTURE_DIRECTORY}"
  mkdir -p "${MOCK_DIRECTORY}" "${APPLICATION_DIRECTORY}" \
    "${MOUNT_DIRECTORY}/etc" "${MOUNT_DIRECTORY}/dev/pts" \
    "${MOUNT_DIRECTORY}/proc" "${MOUNT_DIRECTORY}/sys" \
    "${MOUNT_DIRECTORY}/run/dbus"
  : >"${IMAGE}"
  : >"${LOG}"
}

write_mocks() {
  printf '%s\n' \
    '#!/bin/sh' \
    'set -u' \
    'COMMAND=${0##*/}' \
    'printf '\''%s:%s\n'\'' "${COMMAND}" "${*}" >>"${ALPINE_TEST_LOG}"' \
    'case "${COMMAND}" in' \
    '  losetup)' \
    '    if [ "${1:-}" = -f ]; then printf '\''%s\n'\'' /dev/loop7; exit 0; fi' \
    '    if [ "${1:-}" = -a ]; then [ -f "${ALPINE_TEST_MOUNTED}" ] && printf '\''%s\n'\'' "/dev/loop7: (${ALPINE_TEST_IMAGE})"; exit 0; fi' \
    '    ;;' \
    '  mount)' \
    '    if [ "${#}" -eq 0 ]; then [ -f "${ALPINE_TEST_MOUNTED}" ] && printf '\''%s\n'\'' "/dev/loop7 on ${ALPINE_TEST_MOUNT} type ext3 (rw)"; exit 0; fi' \
    '    ;;' \
    '  chroot)' \
    '    exit "${ALPINE_TEST_CHROOT_STATUS:-0}"' \
    '    ;;' \
    'esac' \
    'if [ "${ALPINE_TEST_FAIL_COMMAND:-}" = "${COMMAND}" ] && printf '\''%s'\'' "${*}" | grep -F "${ALPINE_TEST_FAIL_MATCH:-}" >/dev/null; then exit 1; fi' \
    'exit 0' \
    >"${MOCK_DIRECTORY}/mock"
  chmod 755 "${MOCK_DIRECTORY}/mock"
  for COMMAND in mount umount losetup chroot sync chmod; do
    ln -s mock "${MOCK_DIRECTORY}/${COMMAND}"
  done
}

run_alpine() {
  env \
    PATH="${MOCK_DIRECTORY}:${PATH}" \
    ALPINE_APPLICATION_DIRECTORY="${APPLICATION_DIRECTORY}" \
    ALPINE_MOUNT_DIRECTORY="${MOUNT_DIRECTORY}" \
    ALPINE_TEST_LOG="${LOG}" \
    ALPINE_TEST_MOUNTED="${FIXTURE_DIRECTORY}/mounted" \
    ALPINE_IMAGE="${IMAGE}" \
    ALPINE_ARCHIVE="${ARCHIVE}" \
    ALPINE_IMAGE_SIZE="${ALPINE_IMAGE_SIZE:-2147483648}" \
    ALPINE_TEST_IMAGE="${IMAGE}" \
    ALPINE_TEST_MOUNT="${MOUNT_DIRECTORY}" \
    ALPINE_TEST_CHROOT_STATUS="${ALPINE_TEST_CHROOT_STATUS:-0}" \
    ALPINE_TEST_FAIL_COMMAND="${ALPINE_TEST_FAIL_COMMAND:-}" \
    ALPINE_TEST_FAIL_MATCH="${ALPINE_TEST_FAIL_MATCH:-}" \
    sh "${RUN_SCRIPT}" "${1}"
}

assert_cleanup_order() {
  grep '^umount:' "${LOG}" | sed 's/^umount://' >"${FIXTURE_DIRECTORY}/cleanup"
  printf '%s\n' \
    "${MOUNT_DIRECTORY}/run/dbus" \
    "${MOUNT_DIRECTORY}/sys" \
    "${MOUNT_DIRECTORY}/proc" \
    "${MOUNT_DIRECTORY}/dev/pts" \
    "${MOUNT_DIRECTORY}/dev" \
    "${MOUNT_DIRECTORY}" \
    >"${FIXTURE_DIRECTORY}/expected-cleanup"
  cmp "${FIXTURE_DIRECTORY}/expected-cleanup" "${FIXTURE_DIRECTORY}/cleanup"
  grep -Fx 'losetup:-d /dev/loop7' "${LOG}"
}

reset_fixture
write_mocks
run_alpine shell
grep -Fx "chroot:${MOUNT_DIRECTORY} /bin/sh" "${LOG}"
assert_cleanup_order

reset_fixture
write_mocks
run_alpine gui
grep -Fx "chroot:${MOUNT_DIRECTORY} /bin/sh /startgui.sh" "${LOG}"
assert_cleanup_order

reset_fixture
write_mocks
ALPINE_TEST_CHROOT_STATUS=23
export ALPINE_TEST_CHROOT_STATUS
if run_alpine gui; then
  exit 1
else
  STATUS=${?}
fi
test "${STATUS}" -eq 23
assert_cleanup_order
unset ALPINE_TEST_CHROOT_STATUS

reset_fixture
write_mocks
ALPINE_TEST_FAIL_COMMAND=mount
ALPINE_TEST_FAIL_MATCH="${MOUNT_DIRECTORY}/proc"
export ALPINE_TEST_FAIL_COMMAND ALPINE_TEST_FAIL_MATCH
if run_alpine shell; then
  exit 1
fi
grep '^umount:' "${LOG}" | sed 's/^umount://' >"${FIXTURE_DIRECTORY}/cleanup"
printf '%s\n' \
  "${MOUNT_DIRECTORY}/dev/pts" \
  "${MOUNT_DIRECTORY}/dev" \
  "${MOUNT_DIRECTORY}" \
  >"${FIXTURE_DIRECTORY}/expected-cleanup"
cmp "${FIXTURE_DIRECTORY}/expected-cleanup" "${FIXTURE_DIRECTORY}/cleanup"
grep -Fx 'losetup:-d /dev/loop7' "${LOG}"
unset ALPINE_TEST_FAIL_COMMAND ALPINE_TEST_FAIL_MATCH

reset_fixture
write_mocks
ALPINE_TEST_FAIL_COMMAND=umount
ALPINE_TEST_FAIL_MATCH="${MOUNT_DIRECTORY}/sys"
export ALPINE_TEST_FAIL_COMMAND ALPINE_TEST_FAIL_MATCH
if run_alpine shell; then
  exit 1
fi
assert_cleanup_order
unset ALPINE_TEST_FAIL_COMMAND ALPINE_TEST_FAIL_MATCH

reset_fixture
write_mocks
touch "${FIXTURE_DIRECTORY}/mounted"
if run_alpine shell; then
  exit 1
fi
test "$(grep -c '^losetup:' "${LOG}")" -eq 0
test "$(grep -c '^chroot:' "${LOG}")" -eq 0

reset_fixture
write_mocks
rm "${IMAGE}"
mkdir "${FIXTURE_DIRECTORY}/archive"
printf '%s' fixture >"${FIXTURE_DIRECTORY}/archive/alpine.ext3"
(cd "${FIXTURE_DIRECTORY}/archive" && zip -q "${ARCHIVE}" alpine.ext3)
ALPINE_IMAGE_SIZE=7
export ALPINE_IMAGE_SIZE
run_alpine shell
test "$(cat "${IMAGE}")" = fixture
test ! -e "${IMAGE}.kpm-install"
test "$(find "${FIXTURE_DIRECTORY}" -maxdepth 1 -name 'alpine.ext3.kpm-*' | wc -l)" -eq 0
unset ALPINE_IMAGE_SIZE

reset_fixture
write_mocks
rm "${IMAGE}"
printf '%s' invalid >"${ARCHIVE}"
if run_alpine shell; then
  exit 1
fi
test ! -e "${IMAGE}"
test ! -e "${IMAGE}.kpm-install"
test "$(grep -c '^losetup:' "${LOG}")" -eq 0
