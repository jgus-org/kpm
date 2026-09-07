set -eu

STOP_SCRIPT=${1}
FIXTURE_DIRECTORY=${TMPDIR}/kindle-hid-passthrough-runtime
MOCK_DIRECTORY=${FIXTURE_DIRECTORY}/bin
APPLICATION_DIRECTORY=${FIXTURE_DIRECTORY}/application
CACHE_DIRECTORY=${FIXTURE_DIRECTORY}/cache
OWNED_PROCESS=${FIXTURE_DIRECTORY}/owned-process
FOREIGN_PROCESS=${FIXTURE_DIRECTORY}/foreign-process
STUCK_PROCESS=${FIXTURE_DIRECTORY}/stuck-process
KILL_LOG=${FIXTURE_DIRECTORY}/kill-log
EXPECTED_PATTERN="^${APPLICATION_DIRECTORY}/dist/ld-linux-armhf[.]so[.]3 --library-path ${APPLICATION_DIRECTORY}/dist ${APPLICATION_DIRECTORY}/dist/main[.]bin --daemon$"

rm -rf "${FIXTURE_DIRECTORY}"
mkdir -p "${MOCK_DIRECTORY}" "${CACHE_DIRECTORY}/com.lzampier.btmanager" "${CACHE_DIRECTORY}/BTManager"
: >"${FOREIGN_PROCESS}"
: >"${KILL_LOG}"

printf '%s\n' \
  '#!/bin/sh' \
  'test "${1}" = -f' \
  'test "${2}" = "${KHP_EXPECTED_PATTERN}"' \
  'if [ -f "${KHP_OWNED_PROCESS}" ]; then printf '\''%s\n'\'' 41; exit 0; fi' \
  'exit 1' \
  >"${MOCK_DIRECTORY}/pgrep"
printf '%s\n' '#!/bin/sh' 'exit 0' >"${MOCK_DIRECTORY}/lipc-set-prop"
printf '%s\n' '#!/bin/sh' 'exit 0' >"${MOCK_DIRECTORY}/sleep"
chmod 755 "${MOCK_DIRECTORY}/pgrep" "${MOCK_DIRECTORY}/lipc-set-prop" "${MOCK_DIRECTORY}/sleep"

export KHP_APPLICATION_DIRECTORY=${APPLICATION_DIRECTORY}
export KHP_WAF_CACHE_DIRECTORY=${CACHE_DIRECTORY}
export KHP_WAIT_LIMIT=2
export KHP_EXPECTED_PATTERN=${EXPECTED_PATTERN}
export KHP_OWNED_PROCESS=${OWNED_PROCESS}
export PATH=${MOCK_DIRECTORY}:${PATH}

kill() {
  printf '%s:%s\n' "${1}" "${2}" >>"${KILL_LOG}"
  if [ ! -f "${STUCK_PROCESS}" ]; then
    rm -f "${OWNED_PROCESS}"
  fi
}

: >"${OWNED_PROCESS}"
. "${STOP_SCRIPT}"
grep -Fx -- '-TERM:41' "${KILL_LOG}"
test -f "${FOREIGN_PROCESS}"
test ! -e "${CACHE_DIRECTORY}/com.lzampier.btmanager"
test ! -e "${CACHE_DIRECTORY}/BTManager"

mkdir -p "${CACHE_DIRECTORY}/com.lzampier.btmanager" "${CACHE_DIRECTORY}/BTManager"
: >"${OWNED_PROCESS}"
: >"${STUCK_PROCESS}"
if (
  . "${STOP_SCRIPT}"
  : >"${FIXTURE_DIRECTORY}/mutated"
); then
  exit 1
fi
test ! -e "${FIXTURE_DIRECTORY}/mutated"
test -d "${CACHE_DIRECTORY}/com.lzampier.btmanager"
test -d "${CACHE_DIRECTORY}/BTManager"
test -f "${FOREIGN_PROCESS}"
