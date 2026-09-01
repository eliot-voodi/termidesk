# Apache SSL — Termidesk 7.0
sudo cp <cert.pem> /etc/ssl/certs/termidesk.crt
sudo cp <key.pem> /etc/ssl/private/termidesk.key
# В VirtualHost *:443:
SSLEngine on
SSLCertificateFile /etc/ssl/certs/termidesk.crt
SSLCertificateKeyFile /etc/ssl/private/termidesk.key

sudo systemctl restart apache2