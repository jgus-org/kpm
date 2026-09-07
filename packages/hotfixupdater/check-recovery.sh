set -eu

UPDATER=${1}
FIXTURE=${TMPDIR}/hotfix-recovery
mkdir -p "${FIXTURE}/bin" "${FIXTURE}/base"
awk '/^alert "HotfixUpdater - Info" "Checking hotfix version/{exit} {print}' "${UPDATER}" >"${FIXTURE}/functions.sh"
sed -i "s#/mnt/us/documents/HotfixUpdater#${FIXTURE}/base#" "${FIXTURE}/functions.sh"
printf '%s\n' extract_and_run >>"${FIXTURE}/functions.sh"
cat >"${FIXTURE}/bin/lipc-set-prop" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"${FIXTURE}/bin/mount" <<EOF
#!/bin/sh
COUNT_FILE=${FIXTURE}/mount-count
COUNT=0
if [ -f "\${COUNT_FILE}" ]; then COUNT=\$(cat "\${COUNT_FILE}"); fi
COUNT=\$((COUNT + 1))
printf '%s' "\${COUNT}" > "\${COUNT_FILE}"
printf '%s\n' "\${*}" >> ${FIXTURE}/mount-log
if [ "\${COUNT}" -eq "\${MOUNT_FAIL_CALL:-0}" ]; then exit 1; fi
EOF
cat >"${FIXTURE}/base/KTPW2" <<'EOF'
#!/bin/sh
mkdir -p "${3}"
printf 'exit 7\n' > "${3}/payload.sh"
EOF
chmod +x "${FIXTURE}/bin/"* "${FIXTURE}/base/KTPW2"
if PATH="${FIXTURE}/bin:${PATH}" sh "${FIXTURE}/functions.sh"; then
  exit 1
fi
test "$(cat "${FIXTURE}/mount-count")" = 2
test "$(tail -n 1 "${FIXTURE}/mount-log")" = '-o remount,ro /'
cat >"${FIXTURE}/base/KTPW2" <<'EOF'
#!/bin/sh
mkdir -p "${3}"
printf 'exit 0\n' > "${3}/payload.sh"
EOF
rm "${FIXTURE}/mount-count" "${FIXTURE}/mount-log"
if PATH="${FIXTURE}/bin:${PATH}" MOUNT_FAIL_CALL=2 sh "${FIXTURE}/functions.sh"; then
  exit 1
fi
test "$(cat "${FIXTURE}/mount-count")" = 3
test "$(tail -n 1 "${FIXTURE}/mount-log")" = '-o remount,ro /'
grep -q 'if ! /bin/sh /var/local/kmc/hotfix/run_hotfix.sh' "${UPDATER}"
