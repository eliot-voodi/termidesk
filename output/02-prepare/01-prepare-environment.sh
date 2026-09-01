#!/bin/bash
# Termidesk 7.0 — подготовка среды функционирования
set -euo pipefail

echo "=== Обновление системы ==="
sudo apt update && sudo apt upgrade -y

echo "=== Репозиторий Astra Linux ==="
echo 'deb https://download.astralinux.ru/astra/stable/1.8_x86-64/repository-main/ 1.8_x86-64 main contrib non-free' | sudo tee /etc/apt/sources.list.d/astra-termidesk.list
sudo apt update

echo "=== Синхронизация времени (NTP) ==="
sudo timedatectl set-ntp true
grep -q 'pool.ntp.org' /etc/systemd/timesyncd.conf 2>/dev/null || echo "NTP=pool.ntp.org" | sudo tee -a /etc/systemd/timesyncd.conf
sudo systemctl restart systemd-timesyncd || true

echo "=== Настройка hostname ==="
hostnamectl status

echo "=== Подключение репозитория Termidesk ==="
echo "deb https://download.termidesk.ru/repo/termidesk-vdi/7.0/ stable main" | sudo tee /etc/apt/sources.list.d/termidesk-vdi.list
sudo apt update

echo "=== Установка termidesk-digsig-keys (ЗПС) ==="
sudo apt install -y termidesk-digsig-keys || echo "Пакет digsig-keys недоступен — пропуск"

echo "=== Проверка портов (firewall) ==="
echo "Откройте порты согласно documentation/termidesk-settings/components-interaction/network-ports.html"

echo "=== Готово ==="