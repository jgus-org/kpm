set -eu

SCRIPTLET=/mnt/us/documents/toggle-ads.sh

if [ -f "${SCRIPTLET}" ] && [ ! -L "${SCRIPTLET}" ] && cmp -s scriptlets/toggle-ads.sh "${SCRIPTLET}"; then
  rm -f "${SCRIPTLET}"
fi
