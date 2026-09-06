#!/bin/sh

set -eu

if [ "${1:-}" = upgrade ]; then
  if [ -f /mnt/us/documents/Gargoyle.sh ] && cmp -s scriptlets/Gargoyle.sh /mnt/us/documents/Gargoyle.sh; then
    rm -f /mnt/us/documents/Gargoyle.sh
  fi
  if [ -f /mnt/us/extensions/gargoyle/.kpm-owner ] && [ "$(cat /mnt/us/extensions/gargoyle/.kpm-owner)" = installed ]; then
    printf '%s' retained >/mnt/us/extensions/gargoyle/.kpm-owner
  fi
  exit 0
fi

if [ ! -f /mnt/us/extensions/gargoyle/.kpm-owner ] || [ "$(cat /mnt/us/extensions/gargoyle/.kpm-owner)" != installed ]; then
  exit 0
fi

rm -f \
  /mnt/us/extensions/gargoyle/dist/advsys \
  /mnt/us/extensions/gargoyle/dist/agility \
  /mnt/us/extensions/gargoyle/dist/alan2 \
  /mnt/us/extensions/gargoyle/dist/alan3 \
  /mnt/us/extensions/gargoyle/dist/bocfel \
  /mnt/us/extensions/gargoyle/dist/fbink \
  /mnt/us/extensions/gargoyle/dist/frotz \
  /mnt/us/extensions/gargoyle/dist/gargoyle \
  /mnt/us/extensions/gargoyle/dist/geas \
  /mnt/us/extensions/gargoyle/dist/git \
  /mnt/us/extensions/gargoyle/dist/glulxe \
  /mnt/us/extensions/gargoyle/dist/gtkrc \
  /mnt/us/extensions/gargoyle/dist/hugo \
  /mnt/us/extensions/gargoyle/dist/jacl \
  /mnt/us/extensions/gargoyle/dist/level9 \
  /mnt/us/extensions/gargoyle/dist/libgarglk.so \
  /mnt/us/extensions/gargoyle/dist/libgarglkmain.a \
  /mnt/us/extensions/gargoyle/dist/libjpeg.a \
  /mnt/us/extensions/gargoyle/dist/libjpeg.so.62 \
  /mnt/us/extensions/gargoyle/dist/libm.so.6 \
  /mnt/us/extensions/gargoyle/dist/magnetic \
  /mnt/us/extensions/gargoyle/dist/nitfol \
  /mnt/us/extensions/gargoyle/dist/scare \
  /mnt/us/extensions/gargoyle/dist/scott \
  /mnt/us/extensions/gargoyle/dist/tadsr
rm -f /mnt/us/extensions/gargoyle/samples/garglk.ini /mnt/us/extensions/gargoyle/samples/garglk.ini.original
rmdir /mnt/us/extensions/gargoyle/dist /mnt/us/extensions/gargoyle/samples 2>/dev/null || true
rm -f /mnt/us/extensions/gargoyle/config.xml /mnt/us/extensions/gargoyle/gargoyle-booklet.sh /mnt/us/extensions/gargoyle/gargoyle.png /mnt/us/extensions/gargoyle/gargoyle.sh /mnt/us/extensions/gargoyle/menu.json
rm -f /mnt/us/extensions/gargoyle/.kpm-owner
rmdir /mnt/us/extensions/gargoyle 2>/dev/null || true
if [ -f /mnt/us/documents/Gargoyle.sh ] && cmp -s scriptlets/Gargoyle.sh /mnt/us/documents/Gargoyle.sh; then
  rm -f /mnt/us/documents/Gargoyle.sh
fi
if [ -d /mnt/us/extensions/gargoyle ]; then
  printf '%s' retained >/mnt/us/extensions/gargoyle/.kpm-owner
fi
