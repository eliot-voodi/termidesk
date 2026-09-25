#!/bin/bash
# ИБ-94: синхронизация времени с NTP
set -euo pipefail
timedatectl status | grep -E 'System clock synchronized|NTP service'
chronyc tracking 2>/dev/null || true
systemctl is-active systemd-timesyncd chronyd ntp 2>/dev/null | head -1