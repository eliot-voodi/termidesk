#!/bin/bash
# ИБ-104
apt list --upgradable 2>/dev/null | grep -i termidesk || echo "OK ИБ-104: нет ожидающих обновлений termidesk"