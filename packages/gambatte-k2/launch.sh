set -eu

ARCHITECTURE=armel
if [ -f /lib/ld-linux-armhf.so.3 ]; then
  ARCHITECTURE=armhf
fi

cd /mnt/us/extensions/gambatte-k2
exec "./gambatte-k2-${ARCHITECTURE}" "${@}"
