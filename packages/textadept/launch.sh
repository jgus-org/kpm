#!/bin/sh

set -eu

exec /mnt/us/extensions/kterm/bin/kterm -e 'env HOME=/mnt/us sh /mnt/us/textadept/run.sh textadept-curses' -k 0 -o R
