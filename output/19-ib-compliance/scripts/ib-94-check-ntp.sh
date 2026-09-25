#!/bin/bash
# ИБ-94 — NTP
set -euo pipefail
timedatectl status
systemctl is-active systemd-timesyncd chronyd 2>/dev/null | grep -q active && echo OK ИБ-94 || { echo FAIL ИБ-94; exit 1; }