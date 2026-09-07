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
  printf '%s\n' "PEKI requires firmware 5.12.2.2 or newer; found ${FIRMWARE_VERSION}" >&2
  exit 1
fi
CURRENT_HOTFIX=$(sed -n 's/^HOTFIX_VERSION=["'\'']\{0,1\}\([^"'\'']*\).*/\1/p' /var/local/kmc/hotfix/libhotfixutils 2>/dev/null)
if [ "${CURRENT_HOTFIX}" != 2.3.7 ]; then
  printf '%s\n' "PEKI requires Universal Hotfix 2.3.7 MAX; found ${CURRENT_HOTFIX:-none}" >&2
  exit 1
fi

exec sh /mnt/us/documents/PEKI/peki.sh
