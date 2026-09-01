#!/bin/bash
set -euo pipefail
sudo mv /home/admin/termidesk-vdi /etc/opt/ 2>/dev/null || true
sudo touch /etc/default/termidesk-vdi.local
cat <<'EOF' | sudo tee /etc/default/termidesk-vdi.local
ETC='/etc/opt/termidesk-vdi'
TEMPLATES_DIR='/etc/opt/termidesk-vdi/templates'

EOF
sudo sed -i "s/^NODE_ROLES=.*/NODE_ROLES='CELERYMAN'/" /etc/opt/termidesk-vdi/termidesk.conf
sudo apt -y install termidesk-vdi
sudo systemctl status termidesk-celery-beat termidesk-celery-worker --no-pager