#!/bin/bash
# ИБ-92 — ротация журналов аудита
set -euo pipefail
grep -E "^LOG_DEEP|^LOG_DIR" /etc/opt/termidesk-vdi/termidesk.conf 2>/dev/null || echo "WARN: LOG_DEEP не найден"
ls -la /var/log/termidesk/audit.log* 2>/dev/null || echo "INFO: включите «Сохранение в файл» в портале → Аудит"
echo "Портал: Аудит → «Количество архивных файлов (7-30)»"