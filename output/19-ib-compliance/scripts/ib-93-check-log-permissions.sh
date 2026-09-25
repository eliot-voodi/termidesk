#!/bin/bash
# ИБ-93
set -euo pipefail
LOG_DIR='/var/log/termidesk'
AUDIT_LOG="/var/log/termidesk/audit.log"
FAIL=0
check_file(){ local f="$1"; [ -e "$f" ] || return 0; local m=$(stat -c '%a' "$f"); echo "$f mode=$m"; case "$m" in 44*|40*) ;; *) echo FAIL ИБ-93; FAIL=1;; esac; }
[ -d "$LOG_DIR" ] && find "$LOG_DIR" -maxdepth 1 -type f | while read f; do check_file "$f"; done
check_file "$AUDIT_LOG"
exit $FAIL