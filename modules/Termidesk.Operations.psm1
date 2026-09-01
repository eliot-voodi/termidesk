# Termidesk 7.0 — эксплуатация (пункты 15–17)

function Get-TermideskSettingsOrNew {
    $s = Read-TermideskSettings
    if ($s) { return $s }
    Copy-Item (Join-Path $Script:TermideskConfig 'termidesk-settings.example.json') (Get-TermideskConfigPath) -Force
    return Read-TermideskSettings
}

function Export-TermideskMonitoringScripts {
    $s = Get-TermideskSettingsOrNew
    $m = $s.monitoring

    $healthConf = @"
HEALTH_CHECK_ACCESS_KEY='$($m.healthCheckAccessKey)'
METRICS_ACCESS_KEY='$($m.metricsAccessKey)'
CELERY_BEAT_HEALTH_CHECK_PORT='$($m.celeryBeatPort)'
CELERY_WORKER_HEALTH_CHECK_PORT='$($m.celeryWorkerPort)'
CELERY_BEAT_HEALTH_CHECK_IP='0.0.0.0'
CELERY_WORKER_HEALTH_CHECK_IP='0.0.0.0'
HEALTH_CHECK_CERT='/etc/opt/termidesk-vdi/healthcheck.pem'
HEALTH_CHECK_KEY='/etc/opt/termidesk-vdi/healthcheck-decrypted.key'
"@

    $checkPs1 = @"
# Health Check — Termidesk 7.0
`$s = Get-Content '$((Get-TermideskConfigPath))' -Raw | ConvertFrom-Json
`$portal = `$s.portal.url
`$key = `$s.monitoring.healthCheckAccessKey
Enable-TermideskTlsBypass
try {
    `$r = Invoke-RestMethod -Uri "`$portal/api/health/?key=`$key" -Method Get
    Write-Host 'Health OK:' (`$r | ConvertTo-Json -Compress) -ForegroundColor Green
} catch { Write-Host "Health FAIL: `$_" -ForegroundColor Red }

# Celery nodes
foreach (`$n in `$s.cluster.celeryManagers) {
    Write-Host "Celery `$(`$n.ip):8103 / 8104"
}
"@

    $zabbix = @"
# Zabbix — шаблон мониторинга Termidesk 7.0
# $(Get-TermideskDocLink -Section zabbix)
# Импортируйте шаблон из документации на сервер: $($m.zabbixServer)

Метрики:
- /api/health/metrics/?key=<METRICS_ACCESS_KEY>
- Инфраструктура -> статус компонентов в портале
- Celery beat/worker health на портах $($m.celeryBeatPort)/$($m.celeryWorkerPort)
"@

    Export-TermideskArtifacts -Section '15-monitoring' -Files @{
        'termidesk.conf.health' = $healthConf
        'health-check.ps1'      = $checkPs1
        'zabbix-setup.md'       = $zabbix
    }
}

function Invoke-TermideskHealthCheckRun {
    Export-TermideskMonitoringScripts
    $script = Get-TermideskOutputPath '15-monitoring/health-check.ps1'
    if (Test-Path $script) { & $script }
    Invoke-TermideskClusterHealthCheck
}

function Export-TermideskBackupScripts {
    $s = Get-TermideskSettingsOrNew
    $b = $s.backup
    $db = $s.database

    $backupDb = @"
#!/bin/bash
# Резервное копирование БД Termidesk
set -euo pipefail
BACKUP_DIR='$($b.backupDir)'
mkdir -p `$BACKUP_DIR
DATE=`$(date +%Y%m%d_%H%M%S)
pg_dump -d $($db.name) -h $($db.host1) -p $($db.port) -U $($db.user) -W --format=t > "`$BACKUP_DIR/termidesk_`${DATE}.tar"
find `$BACKUP_DIR -name '*.tar' -mtime +$($b.retentionDays) -delete
echo "Backup: `$BACKUP_DIR/termidesk_`${DATE}.tar"
"@

    $backupConfig = @"
#!/bin/bash
set -euo pipefail
BACKUP_DIR='$($b.backupDir)/config'
mkdir -p `$BACKUP_DIR
DATE=`$(date +%Y%m%d_%H%M%S)
sudo tar czf "`$BACKUP_DIR/termidesk-config_`${DATE}.tar.gz" /etc/opt/termidesk-vdi /etc/default/termidesk-vdi.local
"@

    $restore = @"
#!/bin/bash
# Восстановление БД
pg_restore -d $($db.name) -h $($db.host1) -p $($db.port) -U $($db.user) -W --format=t <backup.tar>
# Конфигурация:
sudo tar xzf termidesk-config_*.tar.gz -C /
cd /opt/termidesk/sbin && sudo ./termidesk-config
"@

    $cron = "$($b.schedule) root $((Get-TermideskOutputPath '16-backup/backup-db.sh').Replace('\','/'))"

    Export-TermideskArtifacts -Section '16-backup' -Files @{
        'backup-db.sh'      = $backupDb
        'backup-config.sh'  = $backupConfig
        'restore-guide.sh'  = $restore
        'cron.example'      = $cron
        'README.txt'        = "Док: $(Get-TermideskDocLink -Section backup)"
    }
}

function Export-TermideskLoggingScripts {
    $s = Get-TermideskSettingsOrNew
    $l = $s.logging

    $conf = @"
LOG_LEVEL='$($l.logLevel)'
LOG_ADDRESS='$($l.logAddress)'
LOG_FACILITY='$($l.logFacility)'
LOG_DIR='$($l.logDir)'
LOG_DEEP='$($l.logDeep)'
LOG_OWNER='termidesk'
LOG_GROUP='adm'
LOG_PERM='0440'
FLUENTD_CACHE='$($l.fluentdCache)'
FLUENTD_TABLE='$($l.fluentdTable)'
FLUENTD_LOGGER_TIMEOUT='$($l.fluentdTimeout)'
INTERNAL_AUDIT='$($l.internalAudit)'
"@

    $syslog = @"
# rsyslog — пересылка журналов Termidesk
# /etc/rsyslog.d/termidesk.conf
if `$programname == 'termidesk' then @$($l.syslogHost):$($l.syslogPort)
& stop
"@

    $audit = @"
# Аудит Termidesk 7.0
# $(Get-TermideskDocLink -Section audit)
# Портал: Система -> Аудит -> Настройки

INTERNAL_AUDIT='$($l.internalAudit)'
# CEF: documentation/termidesk-settings/audit/cef.html
CEF_ENABLED='$($l.cefEnabled)'
"@

    $fluentd = @"
# Fluentd / Ретранслятор
# FLUENTD_TABLE='$($l.fluentdTable)'
# Подключение к узлу Ретранслятора через termidesk-config
"@

    Export-TermideskArtifacts -Section '17-logging' -Files @{
        'termidesk.conf.logging' = $conf
        'rsyslog-termidesk.conf' = $syslog
        'audit-settings.md'      = $audit
        'fluentd-notes.txt'      = $fluentd
        'README.txt'             = "Док: $(Get-TermideskDocLink -Section logging)"
    }
}

function Edit-TermideskMonitoringWizard {
    $s = Get-TermideskSettingsOrNew
    $s.monitoring.healthCheckAccessKey = Invoke-TermideskPrompt -Caption 'HEALTH_CHECK_ACCESS_KEY' -Default $s.monitoring.healthCheckAccessKey -AllowEmpty
    $s.monitoring.metricsAccessKey = Invoke-TermideskPrompt -Caption 'METRICS_ACCESS_KEY' -Default $s.monitoring.metricsAccessKey -AllowEmpty
    $s.monitoring.zabbixServer = Invoke-TermideskPrompt -Caption 'Zabbix server' -Default $s.monitoring.zabbixServer
    Save-TermideskSettings -Settings $s
    Export-TermideskMonitoringScripts
}

function Edit-TermideskBackupWizard {
    $s = Get-TermideskSettingsOrNew
    $s.backup.backupDir = Invoke-TermideskPrompt -Caption 'Каталог бэкапов' -Default $s.backup.backupDir
    $s.backup.retentionDays = [int](Invoke-TermideskPrompt -Caption 'Хранить (дней)' -Default ([string]$s.backup.retentionDays))
    $s.backup.schedule = Invoke-TermideskPrompt -Caption 'Cron расписание' -Default $s.backup.schedule
    Save-TermideskSettings -Settings $s
    Export-TermideskBackupScripts
}

function Edit-TermideskLoggingWizard {
    $s = Get-TermideskSettingsOrNew
    $s.logging.logLevel = Invoke-TermideskPrompt -Caption 'LOG_LEVEL' -Default $s.logging.logLevel
    $s.logging.syslogHost = Invoke-TermideskPrompt -Caption 'Syslog host' -Default $s.logging.syslogHost -AllowEmpty
    $s.logging.internalAudit = (Read-Host 'INTERNAL_AUDIT? (y/N)') -match '^[yY]'
    Save-TermideskSettings -Settings $s
    Export-TermideskLoggingScripts
}

function Export-TermideskAllArtifacts {
    $s = Get-TermideskSettingsOrNew
    Write-Host 'Генерация всех артефактов...' -ForegroundColor Cyan
    Export-TermideskPrepareScripts
    Export-TermideskDatabaseScripts
    Export-TermideskRabbitMqScripts
    Export-TermideskOpenBaoScripts
    Export-TermideskClusterArtifacts -Config (Read-TermideskConfig)
    if (Get-Command Export-TermideskHaWizardArtifacts -ErrorAction SilentlyContinue) {
        $ha = Read-TermideskSettings
        if ($ha -and $ha.cluster -and $ha.cluster.tls) {
            Export-TermideskHaWizardArtifacts -Settings $ha
        }
    }
    Export-TermideskDispatcherScripts
    Export-TermideskCeleryScripts
    Export-TermideskGatewayScripts
    Export-TermideskNginxScripts
    Export-TermideskSslScripts
    Export-TermideskConfigToolScripts
    Export-TermideskDomainScripts
    Export-TermideskProviderScripts
    Export-TermideskPoolScripts
    Export-TermideskAggregatorScripts
    Export-TermideskMonitoringScripts
    Export-TermideskBackupScripts
    Export-TermideskLoggingScripts
    Write-Host "Все артефакты: $(Get-TermideskOutputPath)" -ForegroundColor Green
}

function Invoke-TermideskMonitoringMenu { Invoke-TermideskSubMenu -Title 'Мониторинг и Health Check' -DocSection 'healthcheck' -Items @{
    '1' = @{ Label = 'Мастер настройки мониторинга'; Action = { Edit-TermideskMonitoringWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты'; Action = { Export-TermideskMonitoringScripts } }
    '3' = @{ Label = 'Запустить проверку'; Action = { Invoke-TermideskHealthCheckRun } }
}}

function Invoke-TermideskBackupMenu { Invoke-TermideskSubMenu -Title 'Резервное копирование' -DocSection 'backup' -Items @{
    '1' = @{ Label = 'Мастер настройки бэкапа'; Action = { Edit-TermideskBackupWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты backup/restore'; Action = { Export-TermideskBackupScripts } }
    '3' = @{ Label = 'Выполнить backup БД (SSH)'; Action = {
        Export-TermideskBackupScripts
        $s = Get-TermideskSettingsOrNew
        $script = Get-Content (Get-TermideskOutputPath '16-backup/backup-db.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $s.database.host1 -ScriptContent $script
        Wait-TermideskKey
    }}
}}

function Invoke-TermideskLoggingMenu { Invoke-TermideskSubMenu -Title 'Журналирование и аудит' -DocSection 'logging' -Items @{
    '1' = @{ Label = 'Мастер настройки журналирования'; Action = { Edit-TermideskLoggingWizard } }
    '2' = @{ Label = 'Сгенерировать конфигурации'; Action = { Export-TermideskLoggingScripts } }
}}

Export-ModuleMember -Function @(
    'Invoke-TermideskMonitoringMenu','Invoke-TermideskBackupMenu',
    'Invoke-TermideskLoggingMenu','Export-TermideskAllArtifacts',
    'Export-TermideskMonitoringScripts','Export-TermideskBackupScripts',
    'Export-TermideskLoggingScripts','Invoke-TermideskHealthCheckRun'
)
