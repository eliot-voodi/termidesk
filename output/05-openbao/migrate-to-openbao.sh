#!/bin/bash
# Миграция секретов в OpenBao — Termidesk 7.0
set -euo pipefail
sudo sed -i "s/^SECRET_STORAGE_METHOD=.*/SECRET_STORAGE_METHOD='openbao'/" /etc/opt/termidesk-vdi/termidesk.conf
sudo -u termidesk bash -c '/opt/termidesk/sbin/termidesk-vdi-manage tdsk_openbao_migrate'
cd /opt/termidesk/sbin && sudo ./termidesk-config
# Перезапуск служб
sudo systemctl restart termidesk-vdi termidesk-celery-beat termidesk-celery-worker 2>/dev/null || true