#!/bin/bash
# ИБ-97 — отделение audit от system logs
set -euo pipefail
grep INTERNAL_AUDIT /etc/opt/termidesk-vdi/termidesk.conf
[ -f /var/log/termidesk/audit.log ] && echo OK ИБ-97: audit.log отдельный || echo FAIL ИБ-97