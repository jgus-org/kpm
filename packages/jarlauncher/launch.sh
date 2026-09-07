set -eu

APPLICATION_DIRECTORY=/mnt/us/extensions/JarLauncher
KTERM=/mnt/us/extensions/kterm/bin/kterm
if [ ! -x "${KTERM}" ]; then
  printf '%s\n' 'kTerm 2.6 or newer is required' >&2
  exit 1
fi

exec "${KTERM}" -e "sh ${APPLICATION_DIRECTORY}/run/start.sh" -k 1 -o O -s 7
