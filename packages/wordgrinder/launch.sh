#!/bin/sh

set -eu

exec /mnt/us/extensions/kterm/bin/kterm -e 'env HOME=/mnt/us sh /mnt/us/wordgrinder/start_wordgrinder.sh' -k 0 -o R
