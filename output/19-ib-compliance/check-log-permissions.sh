#!/bin/bash
# ИБ-93: защита локальных журналов от несанкционированного доступа
set -euo pipefail
LOG_DIR='/var/log/termidesk'
AUDIT_LOG="/var/log/termidesk/audit.log"
FAIL=0

check_file() {
  local f="$1"
  [ -e "$f" ] || return 0
  local mode=$(stat -c '%a' "$f")
  local owner=$(stat -c '%U:%G' "$f")
  echo "$f mode=$mode owner=$owner"
  case "$mode" in
    44*|40*) ;;
    *) echo "FAIL ИБ-93: ожидаются права 0440 или строже для $f"; FAIL=1 ;;
  esac
}

[ -d "$LOG_DIR" ] && find "$LOG_DIR" -maxdepth 1 -type f -name '*.log*' | while read -r f; do check_file "$f"; done
check_file "$AUDIT_LOG"
exit $FAIL