#!/bin/bash
# ИБ-96 — атрибуты событий аудита
set -euo pipefail
F=/var/log/termidesk/audit.log
[ -f "$F" ] && tail -5 "$F" || echo "Включите audit.log в портале"
echo "Сверьте с: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-settings/audit/"