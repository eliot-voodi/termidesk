#!/bin/bash
# ИБ-95 — syslog → SIEM
set -euo pipefail
H='siem.corp.example.ru'
P='514'
echo "Настройте портал: Аудит → Syslog host=$H port=$P"
sudo tee /etc/rsyslog.d/termidesk-audit.conf <<EOF
if $programname == 'termidesk' and $msg contains 'AUDIT' then @${H}:${P}
& stop
EOF
sudo systemctl restart rsyslog 2>/dev/null || true
echo OK ИБ-95: rsyslog configured