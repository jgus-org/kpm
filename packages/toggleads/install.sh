set -eu

SCRIPTLET=/mnt/us/documents/toggle-ads.sh
STAGING=/mnt/us/documents/.kpm-toggleads-${$}
trap 'rm -f "${STAGING}"' EXIT HUP INT TERM

if [ -e "${SCRIPTLET}" ] && ! cmp -s scriptlets/toggle-ads.sh "${SCRIPTLET}"; then
  echo 'existing toggle-ads.sh is not owned by this package' >&2
  exit 1
fi

mkdir -p /mnt/us/documents
cp scriptlets/toggle-ads.sh "${STAGING}"
mv "${STAGING}" "${SCRIPTLET}"
trap - EXIT HUP INT TERM
