#!/bin/bash
set -euo pipefail

# Existing VMs keep their old memory allocation until restarted.
if ! grep -q '^/swapfile ' /proc/swaps; then
  if [ ! -f /swapfile ] || [ "$(stat -c%s /swapfile)" -lt 1073741824 ]; then
    dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
  fi
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
fi
if ! grep -qE '^/swapfile[[:space:]]' /etc/fstab; then
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab
fi

dnf install -y memcached firewalld

mkdir -p /etc/systemd/system/memcached.service.d
cat > /etc/systemd/system/memcached.service.d/network.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/memcached -u memcached -p 11211 -U 0 -l 0.0.0.0 -m 128
EOF
systemctl daemon-reload
systemctl enable --now memcached
systemctl restart memcached

systemctl enable --now firewalld
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.56.0/24" port port="11211" protocol="tcp" accept'
firewall-cmd --reload
