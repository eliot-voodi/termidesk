#!/bin/bash
set -euo pipefail
BACKUP_DIR='/var/backups/termidesk/config'
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)
sudo tar czf "$BACKUP_DIR/termidesk-config_${DATE}.tar.gz" /etc/opt/termidesk-vdi /etc/default/termidesk-vdi.local