#!/bin/bash
# ИБ-119 — проверка TLS (укажите FQDN)
HOST="${1:-localhost}"
echo | openssl s_client -connect "${HOST}:443" -tls1_2 2>/dev/null | grep Protocol