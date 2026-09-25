#!/bin/bash
# Генерация CA и пользовательского сертификата для mTLS Termidesk
# Результат: /etc/opt/termidesk-vdi/mtls/{ca.crt,client.crt,client.key}
set -euo pipefail

CN="${1:-termidesk-user}"
DAYS="${2:-365}"
OUT="/etc/opt/termidesk-vdi/mtls"
sudo mkdir -p "$OUT"
cd "$OUT"

if [ ! -f ca.key ]; then
  sudo openssl genrsa -out ca.key 4096
  sudo openssl req -x509 -new -nodes -key ca.key -sha256 -days $DAYS \
    -subj "/CN=Termidesk-Internal-CA" -out ca.crt
fi

sudo openssl genrsa -out client.key 2048
sudo openssl req -new -key client.key -subj "/CN=$CN" -out client.csr
sudo openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days $DAYS -sha256
sudo rm -f client.csr ca.srl
sudo chmod 640 client.key
sudo chown root:termidesk client.key client.crt ca.crt 2>/dev/null || true

echo "CA: $OUT/ca.crt"
echo "Клиент: $OUT/client.crt + $OUT/client.key"
echo "Импортируйте ca.crt в доверенные на клиенте; client.p12 — через openssl pkcs12 при необходимости."