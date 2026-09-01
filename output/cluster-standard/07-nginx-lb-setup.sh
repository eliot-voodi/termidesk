#!/bin/bash
# Termidesk 7.0 — настройка nginx балансировщика
# Документация: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-settings/settings/distributed-config.html
set -euo pipefail

FQDN="portal.termidesk.local"

echo "=== Установка nginx ==="
sudo apt install -y nginx openssl

echo "=== Самоподписанный сертификат ==="
sudo openssl req -new -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt \
  -subj "/CN=\"

sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096

sudo mkdir -p /etc/nginx/snippets
cat <<'SELF_EOF' | sudo tee /etc/nginx/snippets/self-signed.conf
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
SELF_EOF

cat <<'SSL_EOF' | sudo tee /etc/nginx/snippets/ssl-params.conf
ssl_protocols TLSv1.3 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 77.88.8.8 77.88.8.1 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
SSL_EOF

SITE="/etc/nginx/sites-available/\.conf"
cat <<'SITE_EOF' | sudo tee "\"
upstream daas-upstream-ws {
 least_conn;
    # PROXY TERMIDESK (Termidesk Connect / Шлюзы)
     server 192.0.2.50:5099;
     server 192.0.2.51:5099;
}

upstream daas-upstream-nodes {
 least_conn;
     # DISPATCHER TERMIDESK (Универсальные диспетчеры)
     server 192.0.2.30:443;
     server 192.0.2.31:443;
}

server {
 listen 0.0.0.0:80;
 listen 0.0.0.0:443 ssl;

  include snippets/self-signed.conf;
  include snippets/ssl-params.conf;

 location /websockify {
        proxy_http_version 1.1;
        proxy_pass http://daas-upstream-ws/;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_connect_timeout 1000;
        proxy_send_timeout 1000;
        proxy_read_timeout 1000;
        send_timeout 1000;

        proxy_buffering off;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 }

 location / {
        proxy_pass https://daas-upstream-nodes/;

        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 }
}

SITE_EOF

sudo ln -sf "\" /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "=== Балансировщик настроен для \ ==="
