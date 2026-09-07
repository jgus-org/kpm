set -eu

BINARY="${1}"
CONFIG="${2}"
TEST_DIRECTORY=/tmp/kpm-button-mapper-lifecycle-test
INSTALLED_BINARY="${TEST_DIRECTORY}/kindle-button-mapper"
DAEMON_PID_FILE="${TEST_DIRECTORY}/daemon.pid"
HELPER_PID_FILE="${TEST_DIRECTORY}/helper.pid"

cleanup() {
  if [ -n "${STOPPED_PID:-}" ]; then
    kill -CONT "${STOPPED_PID}" >/dev/null 2>&1 || true
  fi
  "${INSTALLED_BINARY}" --kpm-stop-all >/dev/null 2>&1 || true
  if [ -n "${FOREIGN_PID:-}" ]; then
    kill "${FOREIGN_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TEST_DIRECTORY}"
}
trap cleanup EXIT HUP INT TERM

rm -rf "${TEST_DIRECTORY}"
mkdir -p "${TEST_DIRECTORY}"
cp "${BINARY}" "${INSTALLED_BINARY}"
cp "${CONFIG}" "${TEST_DIRECTORY}/config.ini"
chmod 755 "${INSTALLED_BINARY}"

test "$("${INSTALLED_BINARY}" --kpm-status)" = 'stopped 0'
"${INSTALLED_BINARY}" --kpm-start "${TEST_DIRECTORY}/config.ini"
FIRST_STATUS="$("${INSTALLED_BINARY}" --kpm-status)"
case "${FIRST_STATUS}" in
'running '[0-9]*) ;;
*) exit 1 ;;
esac
"${INSTALLED_BINARY}" --kpm-start "${TEST_DIRECTORY}/config.ini"
test "$("${INSTALLED_BINARY}" --kpm-status)" = "${FIRST_STATUS}"
"${INSTALLED_BINARY}" --kpm-start-helper "${TEST_DIRECTORY}/config.ini"
curl --fail --silent http://127.0.0.1:8322/health | grep -Fx '{"ok":true}'
"${INSTALLED_BINARY}" --kpm-stop-all
test "$("${INSTALLED_BINARY}" --kpm-status)" = 'stopped 0'
test ! -e "${DAEMON_PID_FILE}"
test ! -e "${HELPER_PID_FILE}"

"${INSTALLED_BINARY}" --kpm-start "${TEST_DIRECTORY}/config.ini" >"${TEST_DIRECTORY}/start-one.log" &
FIRST_START_PID=${!}
"${INSTALLED_BINARY}" --kpm-start "${TEST_DIRECTORY}/config.ini" >"${TEST_DIRECTORY}/start-two.log" &
SECOND_START_PID=${!}
wait "${FIRST_START_PID}"
wait "${SECOND_START_PID}"
case "$("${INSTALLED_BINARY}" --kpm-status)" in
'running '[0-9]*) ;;
*) exit 1 ;;
esac
"${INSTALLED_BINARY}" --kpm-stop-all

"${INSTALLED_BINARY}" --kpm-start "${TEST_DIRECTORY}/config.ini"
STOPPED_PID="$("${INSTALLED_BINARY}" --kpm-status | awk '{print $2}')"
kill -STOP "${STOPPED_PID}"
if "${INSTALLED_BINARY}" --kpm-stop-all; then
  exit 1
fi
kill -0 "${STOPPED_PID}"
test -e "${DAEMON_PID_FILE}"
kill -CONT "${STOPPED_PID}"
"${INSTALLED_BINARY}" --kpm-stop-all
test ! -e "${DAEMON_PID_FILE}"
STOPPED_PID=

sleep 30 &
FOREIGN_PID=${!}
FOREIGN_START_TIME="$(awk '{print $22}' "/proc/${FOREIGN_PID}/stat")"
printf '%s %s' "${FOREIGN_PID}" "${FOREIGN_START_TIME}" >"${DAEMON_PID_FILE}"
"${INSTALLED_BINARY}" --kpm-stop
kill -0 "${FOREIGN_PID}"
test ! -e "${DAEMON_PID_FILE}"
kill "${FOREIGN_PID}"
wait "${FOREIGN_PID}" 2>/dev/null || true
FOREIGN_PID=
