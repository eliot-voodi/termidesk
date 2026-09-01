#!/bin/bash
cd /opt/termidesk/sbin/
sudo ./termidesk-config
sudo systemctl restart termidesk-vdi
sudo systemctl restart termidesk-celery-beat termidesk-celery-worker 2>/dev/null || true