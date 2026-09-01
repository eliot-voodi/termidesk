#!/bin/bash
sudo -u termidesk bash -c '/opt/termidesk/sbin/termidesk-vdi-manage tdsk_openbao_reverse_migrate'
sudo sed -i "s/^SECRET_STORAGE_METHOD=.*/SECRET_STORAGE_METHOD='config'/" /etc/opt/termidesk-vdi/termidesk.conf