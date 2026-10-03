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

rpm --import \
  https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc \
  https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key \
  https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key

cat > /etc/yum.repos.d/rabbitmq.repo <<'EOF'
[modern-erlang]
name=RabbitMQ modern Erlang for EL 9 - $basearch
baseurl=https://yum1.rabbitmq.com/erlang/el/9/$basearch
        https://yum2.rabbitmq.com/erlang/el/9/$basearch
enabled=1
gpgcheck=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt

[modern-erlang-noarch]
name=RabbitMQ modern Erlang for EL 9 - noarch
baseurl=https://yum1.rabbitmq.com/erlang/el/9/noarch
        https://yum2.rabbitmq.com/erlang/el/9/noarch
enabled=1
gpgcheck=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt

[rabbitmq]
name=RabbitMQ server for EL 9 - $basearch
baseurl=https://yum1.rabbitmq.com/rabbitmq/el/9/$basearch
        https://yum2.rabbitmq.com/rabbitmq/el/9/$basearch
enabled=1
gpgcheck=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
       https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt

[rabbitmq-noarch]
name=RabbitMQ server for EL 9 - noarch
baseurl=https://yum1.rabbitmq.com/rabbitmq/el/9/noarch
        https://yum2.rabbitmq.com/rabbitmq/el/9/noarch
enabled=1
gpgcheck=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
       https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

dnf install -y erlang rabbitmq-server firewalld

cat > /etc/rabbitmq/rabbitmq.conf <<'EOF'
loopback_users = none
EOF

systemctl enable --now rabbitmq-server
rabbitmqctl await_startup
if rabbitmqctl list_users -q | awk '{print $1}' | grep -Fxq test; then
  rabbitmqctl change_password test test
else
  rabbitmqctl add_user test test
fi
rabbitmqctl set_user_tags test administrator
rabbitmqctl set_permissions -p / test ".*" ".*" ".*"

systemctl enable --now firewalld
firewall-cmd --permanent --add-port=5672/tcp
firewall-cmd --reload
