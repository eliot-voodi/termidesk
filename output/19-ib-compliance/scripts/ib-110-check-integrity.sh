#!/bin/bash
# ИБ-110/130 — см. check-integrity.sh
DIR="$(dirname "$0")/.."
bash "$DIR/check-integrity.sh" "${1:-/var/lib/termidesk/baseline.sha256}" "${2:-}"