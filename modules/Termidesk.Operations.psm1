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
    Export-TermideskIbComplianceScripts
    Write-Host "Все артефакты: $(Get-TermideskOutputPath)" -ForegroundColor Green
}

function Export-TermideskIbComplianceScripts {
    $s = Get-TermideskSettingsOrNew
    $l = $s.logging
    $portal = $s.portal.url
    $healthKey = $s.monitoring.healthCheckAccessKey

    $checkLogDisk = @"
#!/bin/bash
# ИБ-91: предупреждение при заполнении каталога журналов
# Использование: sudo bash check-audit-log-disk.sh [порог_процентов]
set -euo pipefail
LOG_DIR='$($l.logDir)'
AUDIT_LOG="/var/log/termidesk/audit.log"
THRESHOLD="`${1:-80}"

check_dir() {
  local dir="`$1"
  [ -d "`$dir" ] || return 0
  local pct=`$(df -P "`$dir" | awk 'NR==2 {print int(`$5)}')
  if [ "`$pct" -ge "`$THRESHOLD" ]; then
    echo "WARNING ИБ-91: заполнение диска для `$dir — `${pct}% (порог `${THRESHOLD}%)"
    return 1
  fi
  echo "OK: `$dir — `${pct}%"
}

check_dir "`$LOG_DIR"
[ -f "`$AUDIT_LOG" ] && check_dir "`$(dirname "`$AUDIT_LOG")"
"@

    $checkLogPerms = @"
#!/bin/bash
# ИБ-93: защита локальных журналов от несанкционированного доступа
set -euo pipefail
LOG_DIR='$($l.logDir)'
AUDIT_LOG="/var/log/termidesk/audit.log"
FAIL=0

check_file() {
  local f="`$1"
  [ -e "`$f" ] || return 0
  local mode=`$(stat -c '%a' "`$f")
  local owner=`$(stat -c '%U:%G' "`$f")
  echo "`$f mode=`$mode owner=`$owner"
  case "`$mode" in
    44*|40*) ;;
    *) echo "FAIL ИБ-93: ожидаются права 0440 или строже для `$f"; FAIL=1 ;;
  esac
}

[ -d "`$LOG_DIR" ] && find "`$LOG_DIR" -maxdepth 1 -type f -name '*.log*' | while read -r f; do check_file "`$f"; done
check_file "`$AUDIT_LOG"
exit `$FAIL
"@

    $checkNtp = @"
#!/bin/bash
# ИБ-94: синхронизация времени с NTP
set -euo pipefail
timedatectl status | grep -E 'System clock synchronized|NTP service'
chronyc tracking 2>/dev/null || true
systemctl is-active systemd-timesyncd chronyd ntp 2>/dev/null | head -1
"@

    $checkIntegrity = @"
#!/bin/bash
# ИБ-110 / ИБ-130: контрольные суммы компонентов Termidesk
set -euo pipefail
BASELINE="`${1:-/var/lib/termidesk/integrity-baseline.sha256}"
PATHS=(/opt/termidesk/sbin/termidesk-config /etc/opt/termidesk-vdi/termidesk.conf)

if [ "`${2:-}" = "create" ]; then
  : > "`$BASELINE"
  for p in "`${PATHS[@]}"; do
    [ -e "`$p" ] && sha256sum "`$p" >> "`$BASELINE"
  done
  echo "Baseline: `$BASELINE"
  exit 0
fi

FAIL=0
while read -r sum path; do
  [ -e "`$path" ] || { echo "MISSING `$path"; FAIL=1; continue; }
  cur=`$(sha256sum "`$path" | awk '{print `$1}')
  [ "`$cur" = "`$sum" ] && echo "OK `$path" || { echo "CHANGED `$path"; FAIL=1; }
done < "`$BASELINE"
exit `$FAIL
"@

    $checkHealthApi = @"
# ИБ-101: интерфейс состояния объектов аудита ИБ (health/metrics API)
`$portal = '$portal'
`$key = '$healthKey'
if (-not `$key) { Write-Host 'Задайте monitoring.healthCheckAccessKey в JSON'; exit 1 }
Enable-TermideskTlsBypass
try {
  `$h = Invoke-RestMethod -Uri "`$portal/api/health/?key=`$key" -Method Get
  Write-Host 'Health API:' (`$h | ConvertTo-Json -Compress)
  `$m = Invoke-RestMethod -Uri "`$portal/api/health/metrics/?key=`$key" -Method Get -ErrorAction SilentlyContinue
  if (`$m) { Write-Host 'Metrics API OK' }
} catch { Write-Host "FAIL: `$_"; exit 1 }
"@

    $skChecklist = @"
# СК-1 … СК-25 — чек-лист совместимости клиентов (Astra Linux Воронеж)

ОС: Astra Linux SE «Воронеж», Яндекс Браузер / нативные клиенты Termidesk / Wine.

| ID | Проверка | Метод | Ожидание |
|----|----------|-------|----------|
| СК-1 | Веб в Яндекс Браузере | Открыть `$portal` | Страница загружается |
| СК-2 | Отображение UI | Визуальный осмотр портала | Без артеfactов вёрстки |
| СК-3 | Работа веб-интерфейса | Логин, навигация, выдача ВРМ | Функции доступны |
| СК-4 | Установка нативного клиента | .deb из репозитория Termidesk | Пакет установлен |
| СК-5 | Запуск нативного клиента | termidesk-connect / tera client | Процесс стартует |
| СК-6 | GUI нативного клиента | Открыть главное окно | Элементы видны |
| СК-7 | Элементы управления | Кнопки, списки, меню | Реагируют |
| СК-8 | Интерактивные элементы | Диалоги, формы | Работают |
| СК-9 | Целевые интеграции | Подключение к фонду/шлюзу | Сессия устанавливается |
| СК-10 | Буфер обмена | Copy/paste в сессии | Данные передаются |
| СК-11 | Р7-Офис | Открыть документ из сессии | Обмен данными OK |
| СК-12 | Файловая система | Доступ к FS из клиента | Операции выполняются |
| СК-13 | Штатный выход | Закрытие клиента | Без зависания |
| СК-14…23 | Wine (Windows-клиент) | wine ./setup.exe; запуск | По матрице вендора |
| СК-24 | Вызов прикладного ПО | URI/handler из клиента | ПО вызывается |
| СК-25 | Запуск вызванного ПО | Проверка процесса в ОС | Процесс запущен |

Скрипт фиксации результатов: `output/19-ib-compliance/sk-report-template.csv`
"@

    $ibGuide = Get-TermideskIbComplianceGuideContent -Settings $s

    Export-TermideskArtifacts -Section '19-ib-compliance' -Files @{
        'README.txt'                    = 'Сценарии апробирования ИБ-91…130 и СК-1…25 для Termidesk VDI 7.0'
        'ИБ-91-130-СЦЕНАРИИ.md'         = $ibGuide
        'СК-1-25-СЦЕНАРИИ.md'            = $skChecklist
        'check-audit-log-disk.sh'       = $checkLogDisk
        'check-log-permissions.sh'      = $checkLogPerms
        'check-ntp-sync.sh'             = $checkNtp
        'check-integrity.sh'            = $checkIntegrity
        'check-health-api.ps1'          = $checkHealthApi
        'configure-audit-syslog.sh'     = (Get-TermideskAuditSyslogScript -Settings $s)
        'sk-report-template.csv'        = "id,scenario,result,notes`nSK-1,Web Yandex Browser,,`n"
        'network-ports-ib102.txt'       = (Get-Content (Get-TermideskOutputPath '02-prepare/firewall-ports.txt') -Raw -ErrorAction SilentlyContinue)
        'incident-response-ib98.md'     = (Get-TermideskIncidentResponseGuide)
    }
    Export-TermideskIbScenarioScripts -Settings $s
    $htmlPath = Export-TermideskIbComplianceHtml -Settings $s
    Write-Host "HTML апробирования: $htmlPath" -ForegroundColor Cyan
    Write-Host "Сценарии ИБ/СК: $(Get-TermideskOutputPath '19-ib-compliance')" -ForegroundColor Green
}

function Get-TermideskAuditSyslogScript {
    param($Settings)
    $host_ = $Settings.logging.syslogHost
    if (-not $host_) { $host_ = 'siem.corp.example.ru' }
    $port = $Settings.logging.syslogPort
    return @"
#!/bin/bash
# ИБ-95: интеграция аудита Termidesk с syslog/SIEM
# Портал: Система -> Аудит -> Отправка в Syslog = Да
set -euo pipefail
CONF="/etc/rsyslog.d/termidesk-audit.conf"
SIEM_HOST="$host_"
SIEM_PORT="$port"
sudo tee "`$CONF" <<EOF
# Termidesk audit -> SIEM
if `$programname == 'termidesk' and `$msg contains 'AUDIT' then @`${SIEM_HOST}:`${SIEM_PORT}
& stop
EOF
sudo systemctl restart rsyslog 2>/dev/null || true
echo "Настройте в портале: Аудит -> Syslog host=$host_, протокол TCP/TLS по политике ИБ"
"@
}

function Get-TermideskIncidentResponseGuide {
    return @"
# ИБ-98: типовые инциденты ИБ и реагирование (Termidesk VDI 7.0)

| Инцидент | Признаки | Действия |
|----------|----------|----------|
| Несанкр. вход в портал | События аудита login failed, алерт SIEM | Блокировка учётки, смена пароля, разбор журнала |
| Компрометация API-токена | Аномальные вызовы API | Отзыв сессий, смена пароля admin, ротация ключей |
| Переполнение журнала аудита | ИБ-91 warning | Архивация, настройка ротации (ИБ-92), расширение тома |
| Расхождение NTP | ИБ-94 fail | Синхронизация chrony/timesyncd, проверка Kerberos/TLS |
| Изменение конфигурации | ИБ-110 checksum fail | Восстановление из backup [16], расследование |
| Уязвимость в компоненте | СМЗИС Critical/High | Обновление пакетов Termidesk, патч ОС |

Журнал аудита: `/var/log/termidesk/audit.log`, БД `termidesk_audit_event_log_v2`.
"@
}

function Get-TermideskIbComplianceGuideContent {
    param($Settings)
    $portal = $Settings.portal.url
    return @"
# Сценарии апробирования ИБ-91 … ИБ-130 (Termidesk VDI 7.0)

Портал: $portal  
Документация аудита: $(Get-TermideskDocLink -Section audit)

## Регистрация и учёт событий ИБ

| ID | Требование | Как проверить | Скрипт/артефакт |
|----|------------|---------------|-----------------|
| ИБ-91 | Предупреждение при заполнении журналов | `sudo bash check-audit-log-disk.sh 80` | output/19-ib-compliance/ |
| ИБ-92 | Перезапись событий при заполнении | Портал: Аудит → «Количество архивных файлов (7-30)»; LOG_DEEP в termidesk.conf | [17] logging |
| ИБ-93 | Защита журналов от просмотра/изменения | `sudo bash check-log-permissions.sh` (ожидается 0440, владелец termidesk) | check-log-permissions.sh |
| ИБ-94 | Синхронизация времени (NTP) | `sudo bash check-ntp-sync.sh`; NTP в [2]/[18] | check-ntp-sync.sh |
| ИБ-95 | Интеграция syslog/database/API с SIEM | Портал: Аудит → Syslog; CEF; rsyslog | configure-audit-syslog.sh |
| ИБ-96 | Соответствие ГОСТ Р 59548-2022 | Сверка типов событий в документации Termidesk «Типы событий аудита» | audit-settings.md |
| ИБ-97 | Журнал ИБ отделён от системных | Отдельный audit.log, INTERNAL_AUDIT=True | /var/log/termidesk/audit.log |
| ИБ-98 | Описание инцидентов в документации | incident-response-ib98.md | см. файл |

## Защита ПО

| ID | Требование | Как проверить |
|----|------------|---------------|
| ИБ-99 | Совместимость с антивирусом | Исключения для /opt/termidesk, /var/log/termidesk по рекомендации Kaspersky/Dr.Web |
| ИБ-100 | Сканирование СМЗИС, нет Critical/High | Отчёт Nexpose/MaxPatrol + актуальные пакеты Termidesk 7.0 |
| ИБ-101 | Интерфейс состояния аудита ИБ | `.\check-health-api.ps1` → /api/health, /api/health/metrics |
| ИБ-102 | Сетевые параметры в документации | network-ports-ib102.txt, firewall-ports.txt |
| ИБ-103 | Замена небезопасных defaults | Смена паролей БД/RabbitMQ/admin [3]→4, [4]→4; HEALTH_CHECK_ACCESS_KEY |
| ИБ-104 | Своевременные обновления | Репозиторий Termidesk 7.0, changelog вендора |
| ИБ-105 | CI/CD для контейнеров | N/A для типовой установки .deb; при контейнеризации — корп. registry |
| ИБ-106 | Настройка по ИБ-7 | НАСТРОЙКА-КЛАСТЕРА.html, политики портала |
| ИБ-107 | Требования ГПН КТ-233 | Матрица соответствия + настройки TLS, аудит, backup |
| ИБ-108 | CI/CD встроенного языка | N/A (Termidesk не содержит встроенного языка разработки) |
| ИБ-109 | Поставка через корп. репозитории | deb-репозиторий Termidesk / Astra |
| ИБ-110 | Контроль целостности | `check-integrity.sh create` затем периодический прогон |
| ИБ-111 | Описание механизмов целостности | check-integrity.sh + документация вендора ЗПС (termidesk-digsig-keys) |
| ИБ-112 | Отказоустойчивое исполнение | HA-кластер [18], ≥2 диспетчеров, шлюзов, LB |
| ИБ-113 | Резервное копирование | [16] backup-db.sh, backup-config.sh, restore-guide.sh |
| ИБ-114 | Прокси белый список | HTTP_PROXY/HTTPS_PROXY на узлах; nginx upstream без прямого Internet |
| ИБ-115 | Front-End / Back-End | nginx VIP (front) + диспетчеры/БД (back) |
| ИБ-116 | Нет неотключаемого Internet | Termidesk не требует постоянного выхода в Internet для лицензии (on-prem) |
| ИБ-117 | Пароли хешированы | PostgreSQL scram-sha-256; scramble в termidesk.conf |
| ИБ-118 | Стойкие хэши | scramble AES256_V2; RabbitMQ password_hash |
| ИБ-119 | TLS 1.2+, AES | cluster.tls в JSON; nginx ssl_protocols TLSv1.2 TLSv1.3 |
| ИБ-120 | Проверка ЭП/сертификата | mTLS [10], домен X.509, user-certificate-auth.md |
| ИБ-121 | Шифрование в КСПД | TLS на VIP и диспетчерах |
| ИБ-122 | Шифрование в ЦДМZ | TLS + разделение сегментов |
| ИБ-123 | Шифрование внутрисистемное | AMQP/TLS, PostgreSQL SSL (DBCERT), HTTPS между компонентами |
| ИБ-124 | Шифрование с внешними ИС | TLS к LDAP, oVirt, SIEM syslog TLS |
| ИБ-125 | Интеграция с PKI | Корпоративные CA на LB и mTLS |
| ИБ-126 | Ключи на отчуждаемом носителе | Smart-card/STAL, Рutoken — по сценарию STAL/Kerberos |
| ИБ-127 | Обезличивание ПДн | Политики домена, минимизация полей аудита |
| ИБ-128 | СКЗИ ГОСТ | При требовании — CryptoPro CSP + совместимые сборки |
| ИБ-129 | Заключение ФСБ по СКЗИ | Документы на используемое СКЗИ |
| ИБ-130 | Контроль целостности по док. | check-integrity.sh |
| ИБ-131 | Нет НДВ (динамический анализ) | Отчёт пентеста / DAST |
| ИБ-132 | Нет НДВ (статический анализ) | SAST исходников — при наличии у вендора |

## Порядок прогона

1. `[A]` или `[19]→2` — сгенерировать артефакты.
2. На эталонном диспетчере: check-ntp, check-log-permissions, check-audit-log-disk.
3. С Windows: `check-health-api.ps1`.
4. Портал: включить аудит, syslog, ротацию (ИБ-92).
5. Зафиксировать результаты в протоколе апробирования.
"@
}

function Invoke-TermideskIbComplianceMenu { Invoke-TermideskSubMenu -Title 'Сценарии ИБ/СК (апробирование)' -Items @{
    '1' = @{ Label = 'Показать гайд ИБ-91…130'; Action = {
        Export-TermideskIbComplianceScripts
        Get-Content (Get-TermideskOutputPath '19-ib-compliance/ИБ-91-130-СЦЕНАРИИ.md') | Write-Host
        Wait-TermideskKey
    }}
    '2' = @{ Label = 'Сгенерировать скрипты, HTML и чек-листы'; Action = { Export-TermideskIbComplianceScripts; Wait-TermideskKey } }
    '6' = @{ Label = 'Открыть ИБ-АПРОБИРОВАНИЕ.html (пошагово + скриншоты)'; Action = {
        Export-TermideskIbComplianceScripts
        $p = Join-Path (Split-Path -Parent $PSScriptRoot) 'ИБ-АПРОБИРОВАНИЕ.html'
        if (Test-Path $p) { Start-Process $p } else { Write-Host 'HTML не создан.' -ForegroundColor Yellow }
        Wait-TermideskKey
    }}
    '3' = @{ Label = 'Показать гайд СК-1…25'; Action = {
        Export-TermideskIbComplianceScripts
        Get-Content (Get-TermideskOutputPath '19-ib-compliance/СК-1-25-СЦЕНАРИИ.md') | Write-Host
        Wait-TermideskKey
    }}
    '4' = @{ Label = 'Запустить check-health-api.ps1 (ИБ-101)'; Action = {
        Export-TermideskIbComplianceScripts
        $script = Get-TermideskOutputPath '19-ib-compliance/check-health-api.ps1'
        if (Test-Path $script) { & $script }
        Wait-TermideskKey
    }}
    '5' = @{ Label = 'Выполнить проверки на диспетчере (SSH)'; Action = {
        Export-TermideskIbComplianceScripts
        $s = Get-TermideskSettingsOrNew
        $ref = $s.cluster.referenceNode.ip
        if (-not $ref) { $ref = Invoke-TermideskPrompt -Caption 'IP эталонного диспетчера' }
        foreach ($name in @('check-ntp-sync.sh','check-log-permissions.sh','check-audit-log-disk.sh')) {
            $path = Get-TermideskOutputPath "19-ib-compliance/$name"
            if (Test-Path $path) {
                Write-Host "=== $name ===" -ForegroundColor Cyan
                $content = Get-Content $path -Raw
                Invoke-TermideskOnNode -HostAddress $ref -ScriptContent $content -ScriptName $name
            }
        }
        Wait-TermideskKey
    }}
}}

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
    'Invoke-TermideskLoggingMenu','Invoke-TermideskIbComplianceMenu',
    'Export-TermideskAllArtifacts','Export-TermideskIbComplianceScripts',
    'Export-TermideskMonitoringScripts','Export-TermideskBackupScripts',
    'Export-TermideskLoggingScripts','Invoke-TermideskHealthCheckRun'
)
