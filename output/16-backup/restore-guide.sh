#!/bin/bash
# Восстановление БД
pg_restore -d termidesk -h 192.0.2.10 -p 5432 -U termideskdb -W --format=t <backup.tar>
# Конфигурация:
sudo tar xzf termidesk-config_*.tar.gz -C /
cd /opt/termidesk/sbin && sudo ./termidesk-config