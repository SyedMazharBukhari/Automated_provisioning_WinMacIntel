#!/bin/bash
set -euo pipefail

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

cat <<'EOT' > /etc/nginx/sites-available/vproapp
upstream vproapp {
    server 192.168.56.12:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://vproapp;
    }
}
EOT

rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/vproapp /etc/nginx/sites-enabled/vproapp

nginx -t
systemctl enable nginx
systemctl restart nginx
