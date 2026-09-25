#!/bin/bash
# Termidesk 7.0 — смена пароля пользователя RabbitMQ
# Запуск: sudo bash 02-change-password.sh 'НовыйПароль'
set -euo pipefail

RMQ_USER='admin'
VHOST='/'
NEW_PASS="${1:-${TERMIDESK_RMQ_NEW_PASS:-}}"

if [ -z "$NEW_PASS" ]; then
  read -rsp "Новый пароль для $RMQ_USER: " NEW_PASS
  echo
fi

sudo rabbitmqctl change_password "$RMQ_USER" "$NEW_PASS"
sudo rabbitmqctl set_permissions -p "$VHOST" "$RMQ_USER" ".*" ".*" ".*"

echo "Пароль RabbitMQ для $RMQ_USER изменён."
echo "Обновите RABBITMQ_PASS и coordinatorPass на диспетчерах, шлюзах и в termidesk.conf."