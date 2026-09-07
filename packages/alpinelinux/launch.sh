set -eu

APPLICATION_DIRECTORY=/mnt/us/extensions/alpinelinux
ARCHIVE=${PWD}/alpine.zip
MODE=${1:-gui}

case "${MODE}" in
gui)
  ALPINE_ARCHIVE=${ARCHIVE} exec sh "${APPLICATION_DIRECTORY}/run.sh" gui >>/mnt/us/alpine.log 2>&1
  ;;
shell)
  KTERM=/mnt/us/extensions/kterm/bin/kterm
  if [ ! -x "${KTERM}" ]; then
    printf '%s\n' 'kTerm 2.6 or newer is required' >&2
    exit 1
  fi
  exec "${KTERM}" -e "ALPINE_ARCHIVE='${ARCHIVE}' sh ${APPLICATION_DIRECTORY}/run.sh shell" -k 1 -o U -s 7
  ;;
*)
  printf '%s\n' "unknown Alpine launch mode: ${MODE}" >&2
  exit 1
  ;;
esac
