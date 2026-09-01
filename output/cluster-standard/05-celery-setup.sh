#!/bin/bash
# Termidesk 7.0 — установка Менеджера рабочих мест (CELERYMAN)
# Active-Active: оба узла обрабатывают задачи, termidesk-celery-beat — active-passive через БД
set -euo pipefail

echo "=== Подготовка каталога конфигурации ==="
# Скопируйте /etc/opt/termidesk-vdi с эталонного диспетчера перед выполнением

sudo touch /etc/default/termidesk-vdi.local
cat <<'LOCAL_EOF' | sudo tee /etc/default/termidesk-vdi.local
ETC='/etc/opt/termidesk-vdi'
TEMPLATES_DIR='/etc/opt/termidesk-vdi/templates'

LOCAL_EOF

echo "=== Установка NODE_ROLES=CELERYMAN ==="
sudo sed -i "s/^NODE_ROLES=.*/NODE_ROLES='CELERYMAN'/" /etc/opt/termidesk-vdi/termidesk.conf

echo "=== Установка пакета ==="
sudo apt -y install termidesk-vdi

echo "=== Проверка служб ==="
sudo systemctl status termidesk-celery-beat --no-pager
sudo systemctl status termidesk-celery-worker --no-pager

echo "=== Рекомендуемые параметры termidesk.conf для HA ==="
echo "CELERY_BEAT_PRIMARY_CHECK_INTERVAL=3"
echo "CELERY_BEAT_PRIMARY_LOCK_TIMEOUT=45"
echo "CELERY_BEAT_HEALTH_CHECK_IP=<IP_этого_узла>"
echo "CELERY_WORKER_HEALTH_CHECK_IP=<IP_этого_узла>"
