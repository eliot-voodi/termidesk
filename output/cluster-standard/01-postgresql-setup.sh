#!/bin/bash
# Termidesk 7.0 — установка и настройка PostgreSQL
# Узел: инфраструктурный сервер СУБД
# Документация: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-install/install-delete/prepare-environment.html

set -euo pipefail

echo "=== Установка PostgreSQL ==="
sudo apt update
sudo apt install -y postgresql

echo "=== Создание БД и пользователя ==="
sudo su - postgres -c "psql -c \"CREATE DATABASE termidesk LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;\"" 2>/dev/null || echo "БД уже существует"
sudo su - postgres -c "psql -c \"CREATE USER termideskdb WITH PASSWORD '';\"" 2>/dev/null || echo "Пользователь уже существует"
sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE termidesk TO termideskdb;\""
sudo su - postgres -c "psql -c \"ALTER DATABASE termidesk OWNER TO termideskdb;\"" 2>/dev/null || true

echo "=== Настройка pg_hba.conf (разрешить подключения Termidesk) ==="
echo "Проверьте listen_addresses и pg_hba.conf для доступа с узлов Termidesk."

echo "=== Готово ==="
echo "DBHOST=192.0.2.10 DBNAME=termidesk DBUSER=termideskdb"
