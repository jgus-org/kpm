set -eu

ARTIFACT="${1}"
RUNTIME="${2}"
FIXTURE="$(mktemp -d)"
TEST_PID_FILE=/tmp/kpm-kindle-button-mapper-daemon.pid
cleanup() {
  if [ -n "${LIVE_PID:-}" ]; then
    kill "${LIVE_PID}" >/dev/null 2>&1 || true
    wait "${LIVE_PID}" 2>/dev/null || true
  fi
  rm -f "${TEST_PID_FILE}"
  rm -rf "${FIXTURE}"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "${FIXTURE}/old" "${FIXTURE}/new" "${FIXTURE}/root/var/local"
tar -xzf "${ARTIFACT}" -C "${FIXTURE}/old"
cp -R "${FIXTURE}/old/." "${FIXTURE}/new/"
sqlite3 "${FIXTURE}/root/var/local/appreg.db" \
  'CREATE TABLE handlerIds(handlerId TEXT PRIMARY KEY); CREATE TABLE properties(handlerId TEXT, name TEXT, value TEXT);'

for PACKAGE_DIRECTORY in "${FIXTURE}/old" "${FIXTURE}/new"; do
  sed \
    -e "s#/var/local#${FIXTURE}/root/var/local#g" \
    -e "s#/mnt/us#${FIXTURE}/root/mnt/us#g" \
    "${PACKAGE_DIRECTORY}/install.sh" >"${PACKAGE_DIRECTORY}/fixture-install.sh"
  sed \
    -e "s#/var/local#${FIXTURE}/root/var/local#g" \
    -e "s#/mnt/us#${FIXTURE}/root/mnt/us#g" \
    "${PACKAGE_DIRECTORY}/uninstall.sh" >"${PACKAGE_DIRECTORY}/fixture-uninstall.sh"
done

(cd "${FIXTURE}/old" && sh fixture-install.sh)
printf '%s' preserved >"${FIXTURE}/root/mnt/us/kindle-button-mapper/config.ini"
cp "${RUNTIME}" "${FIXTURE}/root/mnt/us/kindle-button-mapper/kindle-button-mapper"
chmod 755 "${FIXTURE}/root/mnt/us/kindle-button-mapper/kindle-button-mapper"
"${FIXTURE}/root/mnt/us/kindle-button-mapper/kindle-button-mapper" 'BEGIN { while (1) system("sleep 1") }' &
LIVE_PID=${!}
printf '%s' stale >"${TEST_PID_FILE}"

if (cd "${FIXTURE}/old" && sh fixture-uninstall.sh upgrade); then
  exit 1
fi
test "$(cat "${FIXTURE}/root/var/local/mesquite/com.lzampier.mappermanager/.kpm-kindle-button-mapper")" = active
test "$(cat "${FIXTURE}/root/mnt/us/kindle-button-mapper/config.ini")" = preserved

if (cd "${FIXTURE}/new" && sh fixture-install.sh upgrade); then
  exit 1
fi
kill -0 "${LIVE_PID}"
test "$(cat "${FIXTURE}/root/var/local/mesquite/com.lzampier.mappermanager/.kpm-kindle-button-mapper")" = active
test "$(cat "${FIXTURE}/root/mnt/us/kindle-button-mapper/config.ini")" = preserved

kill "${LIVE_PID}"
wait "${LIVE_PID}" 2>/dev/null || true
LIVE_PID=
printf '%s\n' '#!/bin/sh' 'exit 0' >"${FIXTURE}/root/mnt/us/kindle-button-mapper/kindle-button-mapper"
chmod 755 "${FIXTURE}/root/mnt/us/kindle-button-mapper/kindle-button-mapper"
(cd "${FIXTURE}/new" && sh fixture-install.sh upgrade)
test "$(cat "${FIXTURE}/root/mnt/us/kindle-button-mapper/config.ini")" = preserved
test "$(cat "${FIXTURE}/root/var/local/mesquite/com.lzampier.mappermanager/.kpm-kindle-button-mapper")" = active
