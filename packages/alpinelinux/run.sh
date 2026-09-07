set -eu

APPLICATION_DIRECTORY=${ALPINE_APPLICATION_DIRECTORY:-/mnt/us/extensions/alpinelinux}
MOUNT_DIRECTORY=${ALPINE_MOUNT_DIRECTORY:-/tmp/alpinelinux}
IMAGE=${ALPINE_IMAGE:-/mnt/us/alpine.ext3}
ARCHIVE=${ALPINE_ARCHIVE:-/mnt/us/kmc/kpm/packages/alpinelinux/alpine.zip}
EXPECTED_IMAGE_SIZE=${ALPINE_IMAGE_SIZE:-2147483648}
MODE=${1:-shell}
IMAGE_TEMPORARY=
IMAGE_LOCK=
LOOP_DEVICE=
ROOT_MOUNTED=0
DEV_MOUNTED=0
PTS_MOUNTED=0
PROC_MOUNTED=0
SYS_MOUNTED=0
DBUS_MOUNTED=0

cleanup() {
  RUN_STATUS=${?}
  CLEANUP_STATUS=0
  trap - EXIT HUP INT TERM

  if [ "${DBUS_MOUNTED}" -eq 1 ]; then
    umount "${MOUNT_DIRECTORY}/run/dbus" || CLEANUP_STATUS=1
  fi
  if [ "${SYS_MOUNTED}" -eq 1 ]; then
    umount "${MOUNT_DIRECTORY}/sys" || CLEANUP_STATUS=1
  fi
  if [ "${PROC_MOUNTED}" -eq 1 ]; then
    umount "${MOUNT_DIRECTORY}/proc" || CLEANUP_STATUS=1
  fi
  if [ "${PTS_MOUNTED}" -eq 1 ]; then
    umount "${MOUNT_DIRECTORY}/dev/pts" || CLEANUP_STATUS=1
  fi
  if [ "${DEV_MOUNTED}" -eq 1 ]; then
    umount "${MOUNT_DIRECTORY}/dev" || CLEANUP_STATUS=1
  fi
  if [ "${ROOT_MOUNTED}" -eq 1 ]; then
    sync || CLEANUP_STATUS=1
    umount "${MOUNT_DIRECTORY}" || CLEANUP_STATUS=1
  fi
  if [ -n "${LOOP_DEVICE}" ]; then
    losetup -d "${LOOP_DEVICE}" || CLEANUP_STATUS=1
  fi
  if [ -n "${IMAGE_TEMPORARY}" ]; then
    rm -f "${IMAGE_TEMPORARY}" || CLEANUP_STATUS=1
  fi
  if [ -n "${IMAGE_LOCK}" ]; then
    rmdir "${IMAGE_LOCK}" || CLEANUP_STATUS=1
  fi

  if [ "${RUN_STATUS}" -eq 0 ] && [ "${CLEANUP_STATUS}" -ne 0 ]; then
    RUN_STATUS=${CLEANUP_STATUS}
  fi
  exit "${RUN_STATUS}"
}

initialize_image() {
  if [ -e "${IMAGE}" ] || [ -L "${IMAGE}" ]; then
    return
  fi
  if [ ! -f "${ARCHIVE}" ]; then
    printf '%s\n' 'Alpine Linux source archive is absent' >&2
    exit 1
  fi

  IMAGE_TEMPORARY=${IMAGE}.kpm-${$}
  IMAGE_LOCK=${IMAGE}.kpm-install
  if ! mkdir "${IMAGE_LOCK}"; then
    printf '%s\n' 'Alpine Linux disk image initialization is already active' >&2
    exit 1
  fi
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM

  if [ -e "${IMAGE}" ] || [ -L "${IMAGE}" ]; then
    printf '%s\n' 'Alpine Linux disk image appeared during initialization' >&2
    exit 1
  fi
  unzip -p "${ARCHIVE}" alpine.ext3 >"${IMAGE_TEMPORARY}"
  ACTUAL_IMAGE_SIZE=$(wc -c <"${IMAGE_TEMPORARY}")
  if [ "${ACTUAL_IMAGE_SIZE}" -ne "${EXPECTED_IMAGE_SIZE}" ]; then
    printf '%s\n' 'Alpine Linux disk image has an unexpected size' >&2
    exit 1
  fi
  if [ -e "${IMAGE}" ] || [ -L "${IMAGE}" ]; then
    printf '%s\n' 'Alpine Linux disk image appeared during initialization' >&2
    exit 1
  fi
  mv "${IMAGE_TEMPORARY}" "${IMAGE}"
  IMAGE_TEMPORARY=
  rmdir "${IMAGE_LOCK}"
  IMAGE_LOCK=
}

case "${MODE}" in
gui | shell) ;;
*)
  printf '%s\n' "unknown Alpine launch mode: ${MODE}" >&2
  exit 1
  ;;
esac

initialize_image

if mount | grep -F " on ${MOUNT_DIRECTORY} " >/dev/null; then
  printf '%s\n' 'Alpine Linux is already running' >&2
  exit 1
fi

mkdir -p "${MOUNT_DIRECTORY}"
LOOP_DEVICE=$(losetup -f) || exit 1
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

losetup "${LOOP_DEVICE}" "${IMAGE}"
mount -t ext3 -o noatime "${LOOP_DEVICE}" "${MOUNT_DIRECTORY}"
ROOT_MOUNTED=1
mount -o bind /dev "${MOUNT_DIRECTORY}/dev"
DEV_MOUNTED=1
mount -o bind /dev/pts "${MOUNT_DIRECTORY}/dev/pts"
PTS_MOUNTED=1
mount -o bind /proc "${MOUNT_DIRECTORY}/proc"
PROC_MOUNTED=1
mount -o bind /sys "${MOUNT_DIRECTORY}/sys"
SYS_MOUNTED=1
mount -o bind /var/run/dbus "${MOUNT_DIRECTORY}/run/dbus"
DBUS_MOUNTED=1
cp /etc/hosts "${MOUNT_DIRECTORY}/etc/hosts"
chmod a+w /dev/shm

if [ "${MODE}" = gui ]; then
  chroot "${MOUNT_DIRECTORY}" /bin/sh /startgui.sh
else
  chroot "${MOUNT_DIRECTORY}" /bin/sh
fi
