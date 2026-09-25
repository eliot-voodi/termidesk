#!/bin/bash
# ИБ-91 — предупреждение при заполнении журналов
set -euo pipefail
LOG_DIR='/var/log/termidesk'
THRESHOLD="${1:-80}"
for dir in "$LOG_DIR" /var/log/termidesk; do
  [ -d "$dir" ] || continue
  pct=$(df -P "$dir" | awk 'NR==2 {print int($5)}')
  if [ "$pct" -ge "$THRESHOLD" ]; then
    echo "WARNING ИБ-91: $dir заполнен на ${pct}%"
    exit 1
  fi
  echo "OK ИБ-91: $dir — ${pct}%"
done