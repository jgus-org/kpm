#!/bin/sh

set -eu

if [ "${1:-}" = upgrade ]; then
  if [ -f /mnt/us/LARK/.kpm-owner ] && [ "$(cat /mnt/us/LARK/.kpm-owner)" = installed ]; then
    printf '%s' retained >/mnt/us/LARK/.kpm-owner
  fi
  exit 0
fi

if [ ! -f /mnt/us/LARK/.kpm-owner ] || [ "$(cat /mnt/us/LARK/.kpm-owner)" != installed ]; then
  exit 0
fi

rm -f \
  /mnt/us/LARK/larkplayer \
  /mnt/us/LARK/larkplayer_pw2 \
  /mnt/us/LARK/start_lark.sh \
  /mnt/us/LARK/libs_hf/libfaad.so.2 \
  /mnt/us/LARK/libs_hf/libfaad_drm.so.2 \
  /mnt/us/LARK/libs_hf/libfaad_drm_fixed.so.2 \
  /mnt/us/LARK/libs_hf/libfaad_fixed.so.2 \
  /mnt/us/LARK/libs_pw2/libfaad.so.2 \
  /mnt/us/LARK/libs_pw2/libfaad_drm.so.2 \
  /mnt/us/LARK/libs_pw2/libfaad_drm_fixed.so.2 \
  /mnt/us/LARK/libs_pw2/libfaad_fixed.so.2
rm -f /mnt/us/documents/lark.sh
rm -f /mnt/us/extensions/lark/config.xml /mnt/us/extensions/lark/menu.json
rm -f /mnt/us/LARK/.kpm-owner
rmdir /mnt/us/LARK/libs_hf /mnt/us/LARK/libs_pw2 /mnt/us/LARK /mnt/us/extensions/lark 2>/dev/null || true
if [ -d /mnt/us/LARK ] || [ -d /mnt/us/extensions/lark ]; then
  mkdir -p /mnt/us/LARK
  printf '%s' retained >/mnt/us/LARK/.kpm-owner
fi
