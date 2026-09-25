#!/bin/bash
# ИБ-110 / ИБ-130: контрольные суммы компонентов Termidesk
set -euo pipefail
BASELINE="${1:-/var/lib/termidesk/integrity-baseline.sha256}"
PATHS=(/opt/termidesk/sbin/termidesk-config /etc/opt/termidesk-vdi/termidesk.conf)

if [ "${2:-}" = "create" ]; then
  : > "$BASELINE"
  for p in "${PATHS[@]}"; do
    [ -e "$p" ] && sha256sum "$p" >> "$BASELINE"
  done
  echo "Baseline: $BASELINE"
  exit 0
fi

FAIL=0
while read -r sum path; do
  [ -e "$path" ] || { echo "MISSING $path"; FAIL=1; continue; }
  cur=$(sha256sum "$path" | awk '{print $1}')
  [ "$cur" = "$sum" ] && echo "OK $path" || { echo "CHANGED $path"; FAIL=1; }
done < "$BASELINE"
exit $FAIL