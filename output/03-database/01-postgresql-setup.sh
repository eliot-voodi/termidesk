#!/bin/bash
# Termidesk 7.0 — PostgreSQL
set -euo pipefail
sudo apt update && sudo apt install -y postgresql

sudo su - postgres -c "psql -c \"CREATE DATABASE termidesk LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"CREATE USER termideskdb WITH PASSWORD '';\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE termidesk TO termideskdb;\""
sudo su - postgres -c "psql -c \"ALTER DATABASE termidesk OWNER TO termideskdb;\"" 2>/dev/null || true

# Astra Linux SE — метки безопасности
sudo useradd -M termideskdb -s /usr/sbin/nologin -d /home/termideskdb 2>/dev/null || true
sudo pdpl-user -i 0 termideskdb 2>/dev/null || true
sudo setfacl -m u:postgres:r /etc/parsec/macdb/$(id -u termideskdb) 2>/dev/null || true

echo "Настройте listen_addresses и pg_hba.conf для узлов Termidesk"