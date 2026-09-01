#!/bin/bash
# Резервное копирование БД Termidesk
set -euo pipefail
BACKUP_DIR='/var/backups/termidesk'
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -d termidesk -h 192.0.2.10 -p 5432 -U termideskdb -W --format=t > "$BACKUP_DIR/termidesk_${DATE}.tar"
find $BACKUP_DIR -name '*.tar' -mtime +14 -delete
echo "Backup: $BACKUP_DIR/termidesk_${DATE}.tar"