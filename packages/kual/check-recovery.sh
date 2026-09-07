set -eu

PEKI=${1}
FIXTURE=${TMPDIR}/peki-recovery
mkdir -p "${FIXTURE}/bin" "${FIXTURE}/documents/PEKI" "${FIXTURE}/booklet" "${FIXTURE}/var"
sed \
  -e "s#/mnt/us/documents/PEKI/KUAL.jar#${FIXTURE}/documents/PEKI/KUAL.jar#" \
  -e "s#/opt/amazon/ebook/booklet/KUALBooklet.jar#${FIXTURE}/booklet/KUALBooklet.jar#g" \
  -e "s#/opt/amazon/ebook/booklet/.kpm-peki-kual#${FIXTURE}/booklet/.kpm-peki-kual#" \
  -e "s#/var/local/appreg.db#${FIXTURE}/var/appreg.db#" \
  "${PEKI}" >"${FIXTURE}/peki.sh"
printf source >"${FIXTURE}/documents/PEKI/KUAL.jar"
cat >"${FIXTURE}/bin/mntroot" <<EOF
#!/bin/sh
printf '%s\n' "\${1}" >> ${FIXTURE}/mount-log
EOF
cat >"${FIXTURE}/bin/sqlite3" <<EOF
#!/bin/sh
cat > ${FIXTURE}/sql-input
exit "\${SQLITE_STATUS:-0}"
EOF
cat >"${FIXTURE}/bin/nohup" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "${FIXTURE}/bin/"*
printf foreign >"${FIXTURE}/booklet/KUALBooklet.jar"
if PATH="${FIXTURE}/bin:${PATH}" sh "${FIXTURE}/peki.sh"; then
  exit 1
fi
test "$(cat "${FIXTURE}/booklet/KUALBooklet.jar")" = foreign
test ! -e "${FIXTURE}/mount-log"
rm "${FIXTURE}/booklet/KUALBooklet.jar"
if PATH="${FIXTURE}/bin:${PATH}" SQLITE_STATUS=1 sh "${FIXTURE}/peki.sh"; then
  exit 1
fi
cmp -s "${FIXTURE}/booklet/KUALBooklet.jar" "${FIXTURE}/documents/PEKI/KUAL.jar"
test "$(cat "${FIXTURE}/booklet/.kpm-peki-kual")" = installed
test "$(cat "${FIXTURE}/mount-log")" = 'rw
ro'
PATH="${FIXTURE}/bin:${PATH}" sh "${FIXTURE}/peki.sh"
test "$(cat "${FIXTURE}/mount-log")" = 'rw
ro'
grep -q 'DELETE FROM "properties"' "${FIXTURE}/sql-input"
