set -eu

SCRIPTLET=/mnt/us/documents/updateblock.sh

if [ -f "${SCRIPTLET}" ] && [ ! -L "${SCRIPTLET}" ] && cmp -s scriptlets/updateblock.sh "${SCRIPTLET}"; then
  rm -f "${SCRIPTLET}"
fi
