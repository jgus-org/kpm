set -eu

GAME=${1:-chess}
if [ "${#}" -gt 0 ]; then
  shift
fi

case "${GAME}" in
chess) EXECUTABLE=glchess ;;
mines) EXECUTABLE=gnomine ;;
*)
  printf '%s\n' "unknown Gnome Games entry: ${GAME}" >&2
  exit 1
  ;;
esac

ARCHITECTURE=armel
if [ -f /lib/ld-linux-armhf.so.3 ]; then
  ARCHITECTURE=armhf
fi

APPLICATION_DIRECTORY=/mnt/us/extensions/gnomegames
export GSETTINGS_SCHEMA_DIR=${APPLICATION_DIRECTORY}/share/glib-2.0/schemas
cd "${APPLICATION_DIRECTORY}"
exec "./bin/${ARCHITECTURE}/${EXECUTABLE}" "${@}"
