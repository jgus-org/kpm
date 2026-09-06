set -eu

SCRIPTLET=/mnt/us/documents/updateblock.sh
STAGING=/mnt/us/documents/.kpm-updateblockstatus-${$}
trap 'rm -f "${STAGING}"' EXIT HUP INT TERM

if [ -e "${SCRIPTLET}" ] && ! cmp -s scriptlets/updateblock.sh "${SCRIPTLET}"; then
  echo 'existing updateblock.sh is not owned by this package' >&2
  exit 1
fi

mkdir -p /mnt/us/documents
cp scriptlets/updateblock.sh "${STAGING}"
mv "${STAGING}" "${SCRIPTLET}"
trap - EXIT HUP INT TERM
