#!/bin/sh

set -eu

APPLICATION_DIRECTORY=/mnt/us/LARK
DOCUMENT_FILE=/mnt/us/documents/lark.sh
EXTENSION_DIRECTORY=/mnt/us/extensions/lark
OWNER_FILE=${APPLICATION_DIRECTORY}/.kpm-owner
TRANSACTION_DIRECTORY=/mnt/us/.kpm-lark-${$}
BACKED_UP=0
APPLICATION_INSTALLED=0
DOCUMENT_INSTALLED=0
EXTENSION_INSTALLED=0
OWNED=0

cleanup() {
  trap - EXIT HUP INT TERM
  if [ "${APPLICATION_INSTALLED}" -eq 1 ]; then
    rm -rf "${APPLICATION_DIRECTORY}"
  fi
  if [ "${DOCUMENT_INSTALLED}" -eq 1 ]; then
    rm -f "${DOCUMENT_FILE}"
  fi
  if [ "${EXTENSION_INSTALLED}" -eq 1 ]; then
    rm -rf "${EXTENSION_DIRECTORY}"
  fi
  if [ "${BACKED_UP}" -eq 1 ]; then
    if [ -e "${TRANSACTION_DIRECTORY}/old/LARK" ]; then
      mv "${TRANSACTION_DIRECTORY}/old/LARK" "${APPLICATION_DIRECTORY}"
      printf '%s' retained >"${OWNER_FILE}"
    fi
    if [ -e "${TRANSACTION_DIRECTORY}/old/lark.sh" ]; then
      mv "${TRANSACTION_DIRECTORY}/old/lark.sh" "${DOCUMENT_FILE}"
    fi
    if [ -e "${TRANSACTION_DIRECTORY}/old/extension" ]; then
      mv "${TRANSACTION_DIRECTORY}/old/extension" "${EXTENSION_DIRECTORY}"
    fi
  fi
  rm -rf "${TRANSACTION_DIRECTORY}"
}

trap cleanup EXIT HUP INT TERM

if [ -f "${OWNER_FILE}" ] && { [ "$(cat "${OWNER_FILE}")" = installed ] || [ "$(cat "${OWNER_FILE}")" = retained ]; }; then
  OWNED=1
elif [ -e "${APPLICATION_DIRECTORY}" ] || [ -e "${DOCUMENT_FILE}" ] || [ -e "${EXTENSION_DIRECTORY}" ]; then
  echo "LARKPlayer files already exist" >&2
  exit 1
fi

if [ "${1:-}" = upgrade ] && [ "${OWNED}" -eq 0 ]; then
  echo "LARKPlayer upgrade handoff is absent" >&2
  exit 1
fi

if [ -e "${TRANSACTION_DIRECTORY}" ]; then
  echo "LARKPlayer transaction path already exists" >&2
  exit 1
fi

mkdir -p "${TRANSACTION_DIRECTORY}/new/LARK" "${TRANSACTION_DIRECTORY}/new/documents" "${TRANSACTION_DIRECTORY}/new/extension" "${TRANSACTION_DIRECTORY}/old"
if [ "${OWNED}" -eq 1 ]; then
  cp -a "${APPLICATION_DIRECTORY}/." "${TRANSACTION_DIRECTORY}/new/LARK/"
  if [ -e "${DOCUMENT_FILE}" ]; then
    cp -a "${DOCUMENT_FILE}" "${TRANSACTION_DIRECTORY}/new/documents/lark.sh"
  fi
  if [ -d "${EXTENSION_DIRECTORY}" ]; then
    cp -a "${EXTENSION_DIRECTORY}/." "${TRANSACTION_DIRECTORY}/new/extension/"
  fi
fi
cp -a payload/LARK/. "${TRANSACTION_DIRECTORY}/new/LARK/"
cp -a payload/documents/lark.sh "${TRANSACTION_DIRECTORY}/new/documents/lark.sh"
cp -a payload/extensions/lark/. "${TRANSACTION_DIRECTORY}/new/extension/"
printf '%s' installed >"${TRANSACTION_DIRECTORY}/new/LARK/.kpm-owner"

if [ "${OWNED}" -eq 1 ]; then
  BACKED_UP=1
  mv "${APPLICATION_DIRECTORY}" "${TRANSACTION_DIRECTORY}/old/LARK"
  if [ -e "${DOCUMENT_FILE}" ]; then
    mv "${DOCUMENT_FILE}" "${TRANSACTION_DIRECTORY}/old/lark.sh"
  fi
  if [ -e "${EXTENSION_DIRECTORY}" ]; then
    mv "${EXTENSION_DIRECTORY}" "${TRANSACTION_DIRECTORY}/old/extension"
  fi
fi

mkdir -p /mnt/us/documents /mnt/us/extensions
mv "${TRANSACTION_DIRECTORY}/new/LARK" "${APPLICATION_DIRECTORY}"
APPLICATION_INSTALLED=1
mv "${TRANSACTION_DIRECTORY}/new/documents/lark.sh" "${DOCUMENT_FILE}"
DOCUMENT_INSTALLED=1
mv "${TRANSACTION_DIRECTORY}/new/extension" "${EXTENSION_DIRECTORY}"
EXTENSION_INSTALLED=1
rm -rf "${TRANSACTION_DIRECTORY}"
BACKED_UP=0
APPLICATION_INSTALLED=0
DOCUMENT_INSTALLED=0
EXTENSION_INSTALLED=0
trap - EXIT HUP INT TERM
