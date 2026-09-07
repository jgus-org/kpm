APPLICATION_DIRECTORY=${KHP_APPLICATION_DIRECTORY:-/mnt/us/kindle_hid_passthrough}
WAF_CACHE_DIRECTORY=${KHP_WAF_CACHE_DIRECTORY:-/var/local/mesquite}
WAIT_LIMIT=${KHP_WAIT_LIMIT:-15}
DAEMON_PATTERN="^${APPLICATION_DIRECTORY}/dist/ld-linux-armhf[.]so[.]3 --library-path ${APPLICATION_DIRECTORY}/dist ${APPLICATION_DIRECTORY}/dist/main[.]bin --daemon$"

lipc-set-prop com.lab126.appmgrd stop app://com.lzampier.btmanager >/dev/null 2>&1 || true
sleep 1

DAEMON_PIDS=$(pgrep -f "${DAEMON_PATTERN}" || true)
if [ -n "${DAEMON_PIDS}" ]; then
  for DAEMON_PID in ${DAEMON_PIDS}; do
    kill -TERM "${DAEMON_PID}" 2>/dev/null || true
  done
fi

WAIT_COUNT=0
while pgrep -f "${DAEMON_PATTERN}" >/dev/null 2>&1; do
  if [ "${WAIT_COUNT}" -ge "${WAIT_LIMIT}" ]; then
    echo 'Kindle HID Passthrough daemon is still running' >&2
    exit 1
  fi
  sleep 1
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

rm -rf "${WAF_CACHE_DIRECTORY}/com.lzampier.btmanager" "${WAF_CACHE_DIRECTORY}/BTManager"
