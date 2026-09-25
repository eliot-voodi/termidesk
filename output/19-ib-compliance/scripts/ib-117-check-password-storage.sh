#!/bin/bash
grep scram-sha-256 /etc/postgresql/*/main/pg_hba.conf 2>/dev/null && echo OK pg_hba scram || echo WARN pg_hba
grep DBPASS /etc/opt/termidesk-vdi/termidesk.conf | grep -v "=''" && echo OK DBPASS set || echo FAIL empty DBPASS