set -eu

cd /mnt/us/documents

iptables -C INPUT -p tcp --dport 25565 -j ACCEPT 2>/dev/null ||
  iptables -I INPUT -p tcp --dport 25565 -j ACCEPT

exec /mnt/us/extensions/kindlecraft/kindlecraft
