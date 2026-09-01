#!/bin/bash
# Установка Универсального диспетчера — Termidesk 7.0
set -euo pipefail
sudo apt install -y termidesk-vdi
cd /opt/termidesk/sbin && sudo ./termidesk-config
# Роли: ADMIN,USER | NODE_NAME: Dispatcher-01
sudo systemctl enable termidesk-vdi && sudo systemctl start termidesk-vdi