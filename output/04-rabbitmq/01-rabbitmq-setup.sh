#!/bin/bash
set -euo pipefail
sudo apt install -y rabbitmq-server
sudo mkdir -p /etc/rabbitmq
cat <<'EOF' | sudo tee /etc/rabbitmq/rabbitmq.conf
## Related doc guide: https://rabbitmq.com/management.html#load-definitions.
management.load_definitions = /etc/rabbitmq/definitions.json
tcp_listen_options.keepalive = true

EOF
cat <<'EOF' | sudo tee /etc/rabbitmq/rabbitmq-env.conf
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

EOF
sudo touch /etc/rabbitmq/definitions.json
sudo chown rabbitmq:rabbitmq /etc/rabbitmq/*
sudo rabbitmq-plugins enable rabbitmq_management
cat <<'EOF' | sudo tee -a /etc/sysctl.conf
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
EOF
sudo sysctl -p
sudo systemctl restart rabbitmq-server && sudo systemctl enable rabbitmq-server
echo "Используйте rabbitmq_password2hash.sh для definitions.json"