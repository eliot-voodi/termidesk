#!/bin/bash
# Termidesk 7.0 — смена пароля пользователя PostgreSQL
# Запуск: sudo bash 02-change-password.sh 'НовыйПароль'
# Или:   export TERMIDESK_DB_NEW_PASS='НовыйПароль'; sudo -E bash 02-change-password.sh
set -euo pipefail

DBUSER='termideskdb'
DBNAME='termidesk'
NEW_PASS="${1:-${TERMIDESK_DB_NEW_PASS:-}}"

if [ -z "$NEW_PASS" ]; then
  read -rsp "Новый пароль для $DBUSER: " NEW_PASS
  echo
fi

sudo su - postgres -c "psql -c \"ALTER USER $DBUSER WITH PASSWORD '$NEW_PASS';\""

echo "Пароль PostgreSQL для $DBUSER изменён."
echo "Обновите DBPASS в /etc/opt/termidesk-vdi/termidesk.conf на всех диспетчерах и CeleryMan."
echo "При OpenBao — обновите секрет в $SECRETS_OPENBAO_DB_PATH и перезапустите termidesk-vdi."