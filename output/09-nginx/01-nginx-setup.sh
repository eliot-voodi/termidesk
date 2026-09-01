#!/bin/bash
set -euo pipefail
FQDN="portal.termidesk.local"
sudo apt install -y nginx openssl
sudo openssl req -new -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=$FQDN"
sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096
sudo mkdir -p /etc/nginx/snippets
echo 'ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt; ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;' | sudo tee /etc/nginx/snippets/self-signed.conf
cat <<'SITE' | sudo tee /etc/nginx/sites-available/${FQDN}.conf
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

SITE
sudo ln -sf /etc/nginx/sites-available/${FQDN}.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx