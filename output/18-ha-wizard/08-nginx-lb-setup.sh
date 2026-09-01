#!/bin/bash
set -euo pipefail
FQDN="portal.termidesk.local"
sudo apt install -y nginx openssl
sudo openssl req -new -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=portal.termidesk.local"
sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096
sudo mkdir -p /etc/nginx/snippets
cat <<'CERT' | sudo tee /etc/nginx/snippets/ssl-cert.conf
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

CERT
cat <<'PARAMS' | sudo tee /etc/nginx/snippets/ssl-params.conf
ssl_protocols TLSv1.3 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 10.0.0.1 10.0.0.2 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";

PARAMS
cat <<'SITE' | sudo tee /etc/nginx/sites-available/${FQDN}.conf
upstream daas-upstream-ws {
 least_conn;
     server 192.0.2.50:5099;
     server 192.0.2.51:5099;
}

upstream daas-upstream-nodes {
 least_conn;
     server 192.0.2.30:443;
     server 192.0.2.31:443;
}

server {
 listen 0.0.0.0:80;
 listen 0.0.0.0:443 ssl ssl;

  include snippets/ssl-cert.conf;
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

SITE
sudo ln -sf /etc/nginx/sites-available/${FQDN}.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx