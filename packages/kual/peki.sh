set -eu

SOURCE_JAR=/mnt/us/documents/PEKI/KUAL.jar
TARGET_JAR=/opt/amazon/ebook/booklet/KUALBooklet.jar
OWNER_FILE=/opt/amazon/ebook/booklet/.kpm-peki-kual
DATABASE=/var/local/appreg.db
TEMP_JAR=${TARGET_JAR}.kpm-${$}
ROOT_WRITABLE=0
INSTALLED=0

restore_root() {
  if [ "${ROOT_WRITABLE}" -eq 1 ]; then
    mntroot ro
  fi
}

cleanup() {
  STATUS=${?}
  trap - EXIT HUP INT TERM
  rm -f "${TEMP_JAR}"
  if [ "${INSTALLED}" -eq 1 ]; then
    rm -f "${TARGET_JAR}" "${OWNER_FILE}"
  fi
  if ! restore_root; then
    STATUS=1
  fi
  exit "${STATUS}"
}

if [ -e "${TARGET_JAR}" ] || [ -L "${TARGET_JAR}" ]; then
  if [ ! -f "${OWNER_FILE}" ] || ! cmp -s "${SOURCE_JAR}" "${TARGET_JAR}"; then
    printf '%s\n' 'A KUAL booklet outside PEKI ownership is installed' >&2
    exit 1
  fi
else
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM
  mntroot rw
  ROOT_WRITABLE=1
  cp "${SOURCE_JAR}" "${TEMP_JAR}"
  chmod 644 "${TEMP_JAR}"
  mv "${TEMP_JAR}" "${TARGET_JAR}"
  INSTALLED=1
  printf '%s' installed >"${OWNER_FILE}"
  mntroot ro
  ROOT_WRITABLE=0
  INSTALLED=0
  trap - EXIT HUP INT TERM
fi

sqlite3 "${DATABASE}" <<'EOF'
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO "handlerIds" VALUES('com.mobileread.ixtab.kindlelauncher');
DELETE FROM "properties" WHERE "handlerId" = 'com.mobileread.ixtab.kindlelauncher';
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','lipcId','com.mobileread.ixtab.kindlelauncher');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','jar','/opt/amazon/ebook/booklet/KUALBooklet.jar');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','maxUnloadTime','45');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','maxGoTime','60');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','maxPauseTime','60');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','default-chrome-style','NH');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','unloadPolicy','unloadOnPause');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','extend-start','Y');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','searchbar-mode','transient');
INSERT INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','supportedOrientation','U');
COMMIT;
EOF

nohup sh -c 'sleep 1; lipc-set-prop com.lab126.appmgrd start app://com.mobileread.ixtab.kindlelauncher'
