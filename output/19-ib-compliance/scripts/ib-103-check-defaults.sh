#!/bin/bash
# ИБ-103 — проверка небезопасных defaults
set -euo pipefail
FAIL=0
grep -E "DBPASS=''|RABBITMQ_PASS=''|password=$" /etc/opt/termidesk-vdi/termidesk.conf 2>/dev/null && FAIL=1
grep -q "HEALTH_CHECK_ACCESS_KEY=''" /etc/opt/termidesk-vdi/termidesk.conf 2>/dev/null && echo "WARN: пустой HEALTH_CHECK_ACCESS_KEY"
[ $FAIL -eq 0 ] && echo OK ИБ-103 || { echo FAIL ИБ-103: смените пароли — вкладка «Замена паролей»; exit 1; }