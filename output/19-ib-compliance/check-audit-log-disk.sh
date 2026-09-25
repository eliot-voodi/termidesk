#!/bin/bash
# ИБ-91: предупреждение при заполнении каталога журналов
# Использование: sudo bash check-audit-log-disk.sh [порог_процентов]
set -euo pipefail
LOG_DIR='/var/log/termidesk'
AUDIT_LOG="/var/log/termidesk/audit.log"
THRESHOLD="${1:-80}"

check_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local pct=$(df -P "$dir" | awk 'NR==2 {print int($5)}')
  if [ "$pct" -ge "$THRESHOLD" ]; then
    echo "WARNING ИБ-91: заполнение диска для $dir — ${pct}% (порог ${THRESHOLD}%)"
    return 1
  fi
  echo "OK: $dir — ${pct}%"
}

check_dir "$LOG_DIR"
[ -f "$AUDIT_LOG" ] && check_dir "$(dirname "$AUDIT_LOG")"