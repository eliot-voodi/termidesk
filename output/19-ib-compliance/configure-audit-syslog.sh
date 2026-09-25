#!/bin/bash
# ИБ-95: интеграция аудита Termidesk с syslog/SIEM
# Портал: Система -> Аудит -> Отправка в Syslog = Да
set -euo pipefail
CONF="/etc/rsyslog.d/termidesk-audit.conf"
SIEM_HOST="siem.corp.example.ru"
SIEM_PORT="514"
sudo tee "$CONF" <<EOF
# Termidesk audit -> SIEM
if $programname == 'termidesk' and $msg contains 'AUDIT' then @${SIEM_HOST}:${SIEM_PORT}
& stop
EOF
sudo systemctl restart rsyslog 2>/dev/null || true
echo "Настройте в портале: Аудит -> Syslog host=siem.corp.example.ru, протокол TCP/TLS по политике ИБ"