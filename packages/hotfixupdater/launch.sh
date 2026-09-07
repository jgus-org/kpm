set -eu

FIRMWARE_VERSION=$(sed -n 's/^Kindle \([0-9][0-9.]*\).*/\1/p' /etc/prettyversion.txt)
if [ -z "${FIRMWARE_VERSION}" ]; then
  printf '%s\n' 'Kindle firmware version is unavailable' >&2
  exit 1
fi
if ! awk -v ACTUAL="${FIRMWARE_VERSION}" -v MINIMUM=5.12.2.2 'BEGIN {
  split(ACTUAL, actual, ".")
  split(MINIMUM, minimum, ".")
  for (i = 1; i <= 4; i++) {
    if (actual[i] + 0 > minimum[i] + 0) exit 0
    if (actual[i] + 0 < minimum[i] + 0) exit 1
  }
  exit 0
}'; then
  printf '%s\n' "HotfixUpdater requires firmware 5.12.2.2 or newer; found ${FIRMWARE_VERSION}" >&2
  exit 1
fi
if [ ! -r /var/local/kmc/hotfix/libhotfixutils ]; then
  printf '%s\n' 'An installed Universal Hotfix is required' >&2
  exit 1
fi

exec sh /mnt/us/documents/HotfixUpdater/updater.sh
