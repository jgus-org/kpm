set -eu

APPLICATION_DIRECTORY=/mnt/us/kindle_hid_passthrough
MODULE_DIRECTORY="${APPLICATION_DIRECTORY}/dist/kindle_hid_passthrough/modules"
DAEMON_PATTERN="^${APPLICATION_DIRECTORY}/dist/ld-linux-armhf[.]so[.]3 --library-path ${APPLICATION_DIRECTORY}/dist ${APPLICATION_DIRECTORY}/dist/main[.]bin --daemon$"

if [ ! -e /dev/uhid ]; then
  SERIAL="$(cat /proc/usid)"
  if [ "${SERIAL#G}" = "${SERIAL}" ]; then
    exit 1
  fi
  CODE_STRING="$(printf '%.3s' "$(printf '%s' "${SERIAL}" | cut -c4-6)")"
  FIRST_CHARACTER="${CODE_STRING%??}"
  REMAINING_CHARACTERS="${CODE_STRING#?}"
  SECOND_CHARACTER="${REMAINING_CHARACTERS%?}"
  THIRD_CHARACTER="${REMAINING_CHARACTERS#?}"
  base32_value() {
    case "${1}" in
    0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9) printf '%s\n' "${1}" ;;
    A) printf '%s\n' 10 ;;
    B) printf '%s\n' 11 ;;
    C) printf '%s\n' 12 ;;
    D) printf '%s\n' 13 ;;
    E) printf '%s\n' 14 ;;
    F) printf '%s\n' 15 ;;
    G) printf '%s\n' 16 ;;
    H) printf '%s\n' 17 ;;
    J) printf '%s\n' 18 ;;
    K) printf '%s\n' 19 ;;
    L) printf '%s\n' 20 ;;
    M) printf '%s\n' 21 ;;
    N) printf '%s\n' 22 ;;
    P) printf '%s\n' 23 ;;
    Q) printf '%s\n' 24 ;;
    R) printf '%s\n' 25 ;;
    S) printf '%s\n' 26 ;;
    T) printf '%s\n' 27 ;;
    U) printf '%s\n' 28 ;;
    V) printf '%s\n' 29 ;;
    W) printf '%s\n' 30 ;;
    X) printf '%s\n' 31 ;;
    *) exit 1 ;;
    esac
  }
  DEVICE_CODE=$(($(base32_value "${FIRST_CHARACTER}") * 1024 + $(base32_value "${SECOND_CHARACTER}") * 32 + $(base32_value "${THIRD_CHARACTER}")))
  case "${DEVICE_CODE}" in
  444 | 617 | 618) CODENAME=heisenberg ;;
  524 | 525 | 537 | 538 | 539 | 540 | 541 | 542 | 543 | 544 | 537 | 538 | 539 | 540) CODENAME=duet ;;
  661 | 662 | 663 | 664 | 737 | 738 | 742 | 743 | 744 | 833 | 834 | 835 | 836 | 839 | 842) CODENAME=zelda ;;
  756 | 759 | 865 | 866 | 867 | 868 | 869 | 870 | 871 | 882 | 883 | 884 | 885 | 886 | 887 | 888 | 889 | 890 | 891 | 892 | 893 | 894 | 895 | 1026 | 1027 | 1240 | 1241 | 1242 | 1243 | 1244 | 1245) CODENAME=rex ;;
  *) exit 1 ;;
  esac
  KERNEL_RELEASE="$(uname -r)"
  BUILD="$(sed -n 's/.*-\([0-9][0-9]*\)[[:space:]]*$/\1/p' /etc/version.txt)"
  test -n "${BUILD}"
  MODULE="${MODULE_DIRECTORY}/uhid-${KERNEL_RELEASE}-${BUILD}-${CODENAME}.ko"
  test -f "${MODULE}"
  /sbin/insmod "${MODULE}"
  if [ ! -e /dev/uhid ] && [ -r /sys/class/misc/uhid/dev ]; then
    DEVICE_NUMBERS="$(cat /sys/class/misc/uhid/dev)"
    DEVICE_MAJOR="${DEVICE_NUMBERS%:*}"
    DEVICE_MINOR="${DEVICE_NUMBERS#*:}"
    mknod /dev/uhid c "${DEVICE_MAJOR}" "${DEVICE_MINOR}"
  fi
  test -e /dev/uhid
fi

if ! pgrep -f "${DAEMON_PATTERN}" >/dev/null 2>&1; then
  "${APPLICATION_DIRECTORY}/kindle-hid-passthrough" --daemon >/dev/null 2>&1 &
fi
