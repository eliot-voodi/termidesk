#!/bin/bash
# Termidesk 7.0 — установка и настройка RabbitMQ
set -euo pipefail

echo "=== Установка RabbitMQ ==="
sudo apt update
sudo apt install -y rabbitmq-server

sudo mkdir -p /etc/rabbitmq

cat <<'RABBITMQ_CONF_EOF' | sudo tee /etc/rabbitmq/rabbitmq.conf
## Related doc guide: https://rabbitmq.com/management.html#load-definitions.
management.load_definitions = /etc/rabbitmq/definitions.json
tcp_listen_options.keepalive = true

RABBITMQ_CONF_EOF

cat <<'RABBITMQ_ENV_EOF' | sudo tee /etc/rabbitmq/rabbitmq-env.conf
# Defaults to rabbit. This can be useful if you want to run more than one node
# per machine - RABBITMQ_NODENAME should be unique per erlang-node-and-machine
# combination. See the clustering on a single machine guide for details:
# http://www.rabbitmq.com/clustering.html#single-machine
#NODENAME=rabbit

# By default RabbitMQ will bind to all interfaces, on IPv4 and IPv6 if
# available. Set this if you only want to bind to one network interface or
# address family.
NODE_IP_ADDRESS=0.0.0.0
# Defaults to 5672.
NODE_PORT=5672

RABBITMQ_ENV_EOF

sudo touch /etc/rabbitmq/definitions.json
sudo chown rabbitmq:rabbitmq /etc/rabbitmq/definitions.json /etc/rabbitmq/rabbitmq.conf /etc/rabbitmq/rabbitmq-env.conf

echo "=== Включение management plugin ==="
sudo rabbitmq-plugins enable rabbitmq_management

echo "=== Настройка tcp keepalive ==="
if ! grep -q tcp_keepalive_time /etc/sysctl.conf 2>/dev/null; then
  cat <<'SYSCTL_EOF' | sudo tee -a /etc/sysctl.conf
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
SYSCTL_EOF
  sudo sysctl -p
fi

echo "=== Перезапуск RabbitMQ ==="
sudo systemctl restart rabbitmq-server
sudo systemctl enable rabbitmq-server

echo ""
echo "ВАЖНО: Задайте пароль через rabbitmq_password2hash.sh из репозитория Termidesk"
echo "       и добавьте пользователя 'admin' в /etc/rabbitmq/definitions.json"
echo "URL для Termidesk: amqp://admin:***@192.0.2.10:5672/"
