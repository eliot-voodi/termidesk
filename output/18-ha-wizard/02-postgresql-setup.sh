#!/bin/bash
set -euo pipefail
sudo apt install -y postgresql
sudo su - postgres -c "psql -c \"CREATE DATABASE termidesk LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"CREATE USER termideskdb WITH PASSWORD '';\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE termidesk TO termideskdb;\""
sudo su - postgres -c "psql -c \"ALTER DATABASE termidesk OWNER TO termideskdb;\"" 2>/dev/null || true
echo "# pg_hba: host termidesk termideskdb 192.0.2.0/24 scram-sha-256"