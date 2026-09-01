#!/bin/bash
set -euo pipefail
echo "=== NTP: pool.ntp.org ==="
grep -q 'pool.ntp.org' /etc/systemd/timesyncd.conf 2>/dev/null || echo "NTP=pool.ntp.org" | sudo tee -a /etc/systemd/timesyncd.conf
sudo systemctl restart systemd-timesyncd || true
echo "deb https://download.termidesk.ru/repo/termidesk-vdi/7.0/ stable main" | sudo tee /etc/apt/sources.list.d/termidesk-vdi.list
echo 'deb https://download.astralinux.ru/astra/stable/1.8_x86-64/repository-main/ 1.8_x86-64 main contrib non-free' | sudo tee /etc/apt/sources.list.d/astra.list
sudo apt update