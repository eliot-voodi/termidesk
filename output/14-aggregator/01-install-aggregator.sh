#!/bin/bash
# Агрегатор Termidesk — отдельный узел, отдельная БД!
set -euo pipefail
sudo apt install -y termidesk-vdi
# termidesk-config: TERMIDESK_FARM_MODE=aggregator, NODE_ROLES=ADMIN,USER
TERMIDESK_FARM_MODE='aggregator'
NODE_NAME='Aggregator-01'
DBHOST='192.0.2.20'
DBNAME='termidesk_aggr'