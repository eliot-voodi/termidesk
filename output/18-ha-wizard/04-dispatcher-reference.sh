#!/bin/bash
# Эталонный диспетчер: disp1.termidesk.local (192.0.2.30)
# NODE_NAME=Dispatcher-01 | NODE_ROLES=ADMIN,USER
sudo apt install -y termidesk-vdi
cd /opt/termidesk/sbin && sudo ./termidesk-config
# DB: 192.0.2.10:5432/termidesk user=termideskdb
# RABBITMQ: 192.0.2.10:5672/
sudo scp -r /etc/opt/termidesk-vdi admin@<target>:/home/admin/