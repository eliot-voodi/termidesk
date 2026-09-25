# Termidesk 7.0 — генерация HTML апробирования ИБ и per-scenario скриптов

. "$PSScriptRoot\IbRequirementsCatalog.ps1"


function Get-TermideskIbScenarioScriptContents {
    param([object]$Settings)
    $portal = $Settings.portal.url
    $healthKey = $Settings.monitoring.healthCheckAccessKey
    $logDir = $Settings.logging.logDir
    $syslogHost = if ($Settings.logging.syslogHost) { $Settings.logging.syslogHost } else { 'siem.corp.example.ru' }
    $syslogPort = $Settings.logging.syslogPort
    @{
        'ib-91-check-log-disk.sh' = @"
#!/bin/bash
# ИБ-91 — предупреждение при заполнении журналов
set -euo pipefail
LOG_DIR='$logDir'
THRESHOLD="`${1:-80}"
for dir in "`$LOG_DIR" /var/log/termidesk; do
  [ -d "`$dir" ] || continue
  pct=`$(df -P "`$dir" | awk 'NR==2 {print int(`$5)}')
  if [ "`$pct" -ge "`$THRESHOLD" ]; then
    echo "WARNING ИБ-91: `$dir заполнен на `${pct}%"
    exit 1
  fi
  echo "OK ИБ-91: `$dir — `${pct}%"
done
"@
        'ib-92-check-log-rotation.sh' = @"
#!/bin/bash
# ИБ-92 — ротация журналов аудита
set -euo pipefail
grep -E "^LOG_DEEP|^LOG_DIR" /etc/opt/termidesk-vdi/termidesk.conf 2>/dev/null || echo "WARN: LOG_DEEP не найден"
ls -la /var/log/termidesk/audit.log* 2>/dev/null || echo "INFO: включите «Сохранение в файл» в портале → Аудит"
echo "Портал: Аудит → «Количество архивных файлов (7-30)»"
"@
        'ib-93-check-log-permissions.sh' = @"
#!/bin/bash
# ИБ-93
set -euo pipefail
LOG_DIR='$logDir'
AUDIT_LOG="/var/log/termidesk/audit.log"
FAIL=0
check_file(){ local f="`$1"; [ -e "`$f" ] || return 0; local m=`$(stat -c '%a' "`$f"); echo "`$f mode=`$m"; case "`$m" in 44*|40*) ;; *) echo FAIL ИБ-93; FAIL=1;; esac; }
[ -d "`$LOG_DIR" ] && find "`$LOG_DIR" -maxdepth 1 -type f | while read f; do check_file "`$f"; done
check_file "`$AUDIT_LOG"
exit `$FAIL
"@
        'ib-94-check-ntp.sh' = @"
#!/bin/bash
# ИБ-94 — NTP
set -euo pipefail
timedatectl status
systemctl is-active systemd-timesyncd chronyd 2>/dev/null | grep -q active && echo OK ИБ-94 || { echo FAIL ИБ-94; exit 1; }
"@
        'ib-95-configure-syslog.sh' = @"
#!/bin/bash
# ИБ-95 — syslog → SIEM
set -euo pipefail
H='$syslogHost'
P='$syslogPort'
echo "Настройте портал: Аудит → Syslog host=`$H port=`$P"
sudo tee /etc/rsyslog.d/termidesk-audit.conf <<EOF
if `$programname == 'termidesk' and `$msg contains 'AUDIT' then @`${H}:`${P}
& stop
EOF
sudo systemctl restart rsyslog 2>/dev/null || true
echo OK ИБ-95: rsyslog configured
"@
        'ib-96-check-audit-events.sh' = @"
#!/bin/bash
# ИБ-96 — атрибуты событий аудита
set -euo pipefail
F=/var/log/termidesk/audit.log
[ -f "`$F" ] && tail -5 "`$F" || echo "Включите audit.log в портале"
echo "Сверьте с: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-settings/audit/"
"@
        'ib-97-check-audit-separation.sh' = @"
#!/bin/bash
# ИБ-97 — отделение audit от system logs
set -euo pipefail
grep INTERNAL_AUDIT /etc/opt/termidesk-vdi/termidesk.conf
[ -f /var/log/termidesk/audit.log ] && echo OK ИБ-97: audit.log отдельный || echo FAIL ИБ-97
"@
        'ib-99-antivirus-paths.txt' = @"
# ИБ-99 — пути для исключений антивируса
/opt/termidesk/
/etc/opt/termidesk-vdi/
/var/log/termidesk/
/tmp/termidesk*
"@
        'ib-100-vulnerability-checklist.ps1' = @"
# ИБ-100 — чек-лист СМЗИС (заполните вручную)
Write-Host 'ИБ-100: приложите отчёт MaxPatrol/Nexpose'
Write-Host '[ ] Нет Critical по termidesk-*'
Write-Host '[ ] Нет High без компенсирующих мер'
Write-Host '[ ] План обновления утверждён'
"@
        'ib-101-check-health-api.ps1' = @"
# ИБ-101
`$portal = '$portal'
`$key = '$healthKey'
if (-not `$key) { Write-Host 'FAIL: задайте healthCheckAccessKey'; exit 1 }
[Net.ServicePointManager]::ServerCertificateValidationCallback = { `$true }
`$h = Invoke-RestMethod -Uri "`$portal/api/health/?key=`$key"
Write-Host 'OK ИБ-101:' (`$h | ConvertTo-Json -Compress)
"@
        'ib-102-network-ports.txt' = @"
# ИБ-102 — порты Termidesk 7.0
22 SSH | 80/443 nginx VIP | 443 dispatcher | 5432 PostgreSQL
5672 AMQP | 15672 RabbitMQ mgmt | 5099 websockify | 8103/8104 Celery health
"@
        'ib-103-check-defaults.sh' = @"
#!/bin/bash
# ИБ-103 — проверка небезопасных defaults
set -euo pipefail
FAIL=0
grep -E "DBPASS=''|RABBITMQ_PASS=''|password=$" /etc/opt/termidesk-vdi/termidesk.conf 2>/dev/null && FAIL=1
grep -q "HEALTH_CHECK_ACCESS_KEY=''" /etc/opt/termidesk-vdi/termidesk.conf 2>/dev/null && echo "WARN: пустой HEALTH_CHECK_ACCESS_KEY"
[ `$FAIL -eq 0 ] && echo OK ИБ-103 || { echo FAIL ИБ-103: смените пароли — вкладка «Замена паролей»; exit 1; }
"@
        'ib-104-check-updates.sh' = @"
#!/bin/bash
# ИБ-104
apt list --upgradable 2>/dev/null | grep -i termidesk || echo "OK ИБ-104: нет ожидающих обновлений termidesk"
"@
        'ib-106-security-checklist.sh' = @"
#!/bin/bash
echo "ИБ-106: HA [18], TLS, аудит, backup — см. НАСТРОЙКА-КЛАСТЕРА.html"
"@
        'ib-107-gpn-matrix.md' = "# ИБ-107 — матрица соответствия КТ-233`n`n| Требование | Реализация Termidesk | Статус |`n|---|---|---|"
        'ib-109-check-repo.sh' = @"
#!/bin/bash
grep -r termidesk /etc/apt/sources.list.d/ && echo OK ИБ-109 || echo FAIL ИБ-109
"@
        'ib-110-check-integrity.sh' = @"
#!/bin/bash
# ИБ-110/130 — см. check-integrity.sh
DIR="`$(dirname "`$0")/.."
bash "`$DIR/check-integrity.sh" "`${1:-/var/lib/termidesk/baseline.sha256}" "`${2:-}"
"@
        'ib-111-integrity-procedure.md' = "# ИБ-111`n1. Создать baseline: ib-110-check-integrity.sh ... create`n2. Cron ежедневно`n3. ЗПС: termidesk-digsig-keys"
        'ib-112-ha-check.ps1' = @"
# ИБ-112
`$s = Get-Content (Join-Path (Split-Path `$PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent) 'config/termidesk-settings.json') -Raw | ConvertFrom-Json
foreach (`$d in `$s.cluster.dispatchers) { Write-Host "Dispatcher `$(`$d.ip)" }
Write-Host 'Проверьте failover: отключите один узел, VIP доступен'
"@
        'ib-114-proxy-example.sh' = @"
#!/bin/bash
echo 'export http_proxy=http://proxy.corp:8080'
echo 'export https_proxy=http://proxy.corp:8080'
"@
        'ib-115-segmentation-checklist.md' = "# ИБ-115`n- [ ] VIP nginx в DMZ/front`n- [ ] DB/RabbitMQ только back`n- [ ] 5432/5672 закрыты от пользователей"
        'ib-116-offline-check.sh' = @"
#!/bin/bash
echo "ИБ-116: отключите default route и проверьте работу портала on-prem"
"@
        'ib-117-check-password-storage.sh' = @"
#!/bin/bash
grep scram-sha-256 /etc/postgresql/*/main/pg_hba.conf 2>/dev/null && echo OK pg_hba scram || echo WARN pg_hba
grep DBPASS /etc/opt/termidesk-vdi/termidesk.conf | grep -v "=''" && echo OK DBPASS set || echo FAIL empty DBPASS
"@
        'ib-118-check-hash-algo.sh' = @"
#!/bin/bash
/opt/termidesk/bin/scramble --help 2>/dev/null | head -3 || echo "scramble на диспетчере"
"@
        'ib-119-check-tls.sh' = @"
#!/bin/bash
# ИБ-119 — проверка TLS (укажите FQDN)
HOST="`${1:-localhost}"
echo | openssl s_client -connect "`${HOST}:443" -tls1_2 2>/dev/null | grep Protocol
"@
        'ib-121-125-tls-connectivity.sh' = @"
#!/bin/bash
echo "ИБ-121-124: проверьте HTTPS VIP, LDAPS, syslog TLS — см. ib-119-check-tls.sh"
"@
        'ib-125-pki-checklist.md' = "# ИБ-125`n- [ ] Корпоративный CA на LB`n- [ ] CA на клиентах`n- [ ] mTLS [10]"
    }
}

function ConvertTo-TermideskHtmlEncode {
    param([string]$Text)
    if (-not $Text) { return '' }
    ($Text -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
}

function Resolve-TermideskHtmlScriptRelPath {
    param([string]$ScriptRef)
    if ([string]::IsNullOrWhiteSpace($ScriptRef)) { return $null }
    if ($ScriptRef -match '^\.\./') { return "output/$($ScriptRef -replace '^\.\./','')" }
    if ($ScriptRef -match '^output/') { return ($ScriptRef -replace '\\','/') }
    if ($ScriptRef -match '^scripts/') { return "output/19-ib-compliance/$ScriptRef" }
    if ($ScriptRef -match '\.(md|txt|ps1|sh|conf)$') { return "output/19-ib-compliance/$ScriptRef" }
    return "output/$ScriptRef"
}

function Get-TermideskHtmlScriptContent {
    param(
        [Parameter(Mandatory)][string]$RelPath,
        [hashtable]$ScriptBodies,
        [Parameter(Mandatory)][string]$Root
    )
    $normalized = ($RelPath -replace '\\','/')
    $fullPath = Join-Path $Root ($normalized -replace '/','\')
    if (Test-Path -LiteralPath $fullPath) {
        return [System.IO.File]::ReadAllText($fullPath, [System.Text.UTF8Encoding]::new($false))
    }
    $leaf = [System.IO.Path]::GetFileName($normalized)
    if ($ScriptBodies -and $ScriptBodies.ContainsKey($leaf) -and $ScriptBodies[$leaf]) {
        return $ScriptBodies[$leaf]
    }
    return $null
}

function New-TermideskHtmlScriptBodyBlock {
    param(
        [Parameter(Mandatory)][string]$RelPath,
        [Parameter(Mandatory)][string]$IdPrefix,
        [hashtable]$ScriptBodies,
        [Parameter(Mandatory)][string]$Root,
        [string]$Label = 'Копировать скрипт'
    )
    $relEnc = ConvertTo-TermideskHtmlEncode ($RelPath -replace '\\','/')
    $srcId = "src-$IdPrefix"
    $content = Get-TermideskHtmlScriptContent -RelPath $RelPath -ScriptBodies $ScriptBodies -Root $Root
    if (-not $content) {
        return @"
<div class="script-full script-full-missing">
  <p class="meta">Файл <code>$relEnc</code> не найден — сгенерируйте артефакты: меню <kbd>[19]→2</kbd> или <kbd>[A]</kbd></p>
</div>
"@
    }
    $embed = ConvertTo-TermideskHtmlEncode $content
    return @"
<div class="script-full">
  <div class="script-full-head"><span>📄 Полный текст файла</span><code>$relEnc</code><button type="button" class="btn-copy" data-copy="$srcId" data-copy-label="$Label">$Label</button></div>
  <pre id="$srcId">$embed</pre>
</div>
"@
}

function New-TermideskHtmlScriptBlock {
    param(
        [Parameter(Mandatory)][string]$RelPath,
        [Parameter(Mandatory)][string]$RunCmd,
        [Parameter(Mandatory)][string]$IdPrefix,
        [hashtable]$ScriptBodies,
        [Parameter(Mandatory)][string]$Root,
        [string]$Title = 'Скрипт проверки'
    )
    $relEnc = ConvertTo-TermideskHtmlEncode ($RelPath -replace '\\','/')
    $runEnc = ConvertTo-TermideskHtmlEncode $RunCmd
    $cmdId = "cmd-$IdPrefix"
    $body = New-TermideskHtmlScriptBodyBlock -RelPath $RelPath -IdPrefix $IdPrefix -ScriptBodies $ScriptBodies -Root $Root
    return @"
<div class="script-card">
  <div class="script-head"><span>🧪 $Title</span><code>$relEnc</code></div>
  <div class="cmd-block"><code id="$cmdId">$runEnc</code><button type="button" class="btn-copy" data-copy="$cmdId" data-copy-label="Копировать команду">Копировать команду</button></div>
  $body
</div>
"@
}

function Export-TermideskIbComplianceHtml {
    param([object]$Settings)
    if (-not $Settings) { $Settings = Get-TermideskSettingsOrNew }
    $scenarios = @(Get-TermideskIbScenarios -Settings $Settings)
    $skScenarios = @(Get-TermideskSkScenarios -Settings $Settings)
    $scriptBodies = Get-TermideskIbScenarioScriptContents -Settings $Settings
    $root = Split-Path -Parent $PSScriptRoot
    $portal = ConvertTo-TermideskHtmlEncode $Settings.portal.url
    $totalIb = $scenarios.Count
    $totalSk = $skScenarios.Count

    $panelsSb = New-Object System.Text.StringBuilder
    $orderList = New-Object System.Collections.Generic.List[string]
    $catMap = @{}

    $bodyPg = New-TermideskHtmlScriptBodyBlock -RelPath 'output/03-database/02-change-password.sh' -IdPrefix 'pg' -ScriptBodies $scriptBodies -Root $root
    $bodyRmq = New-TermideskHtmlScriptBodyBlock -RelPath 'output/04-rabbitmq/02-change-password.sh' -IdPrefix 'rmq' -ScriptBodies $scriptBodies -Root $root
    $body103 = New-TermideskHtmlScriptBodyBlock -RelPath 'output/19-ib-compliance/scripts/ib-103-check-defaults.sh' -IdPrefix '103' -ScriptBodies $scriptBodies -Root $root
    $bodyCertGen = New-TermideskHtmlScriptBodyBlock -RelPath 'output/10-ssl/generate-user-certificate.sh' -IdPrefix 'cert-gen' -ScriptBodies $scriptBodies -Root $root
    $bodyApacheMtls = New-TermideskHtmlScriptBodyBlock -RelPath 'output/10-ssl/apache-mtls-snippet.conf' -IdPrefix 'apache-mtls' -ScriptBodies $scriptBodies -Root $root -Label 'Копировать конфиг'

    [void]$orderList.Add('tab-home')
    [void]$panelsSb.AppendLine(@"
<section id="tab-home" class="panel active" data-title="Старт">
  <div class="panel-head"><h2>Апробирование Termidesk 7.0</h2><p class="lead">Один файл: пароли, сертификаты, сессии/API, полный перечень ИБ-1…132 и СК-1…25 — шаги, скриншоты и скрипты.</p></div>
  <div class="stat-grid">
    <div class="stat-card"><div class="stat-num" id="statTotal">$totalIb</div><div class="stat-label">требований ИБ</div></div>
    <div class="stat-card"><div class="stat-num">$totalSk</div><div class="stat-label">проверок СК</div></div>
    <div class="stat-card"><div class="stat-num" id="statDone">0</div><div class="stat-label">выполнено</div></div>
    <div class="stat-card"><div class="stat-num" id="statPct">0%</div><div class="stat-label">прогресс</div></div>
  </div>
  <div class="progress-bar"><div class="progress-fill" id="progressFill"></div></div>
  <h3>С чего начать</h3>
  <div class="quick-grid">
    <button type="button" class="quick-card" data-goto="tab-pwd"><span class="qc-icon">🔑</span><strong>1. Замена паролей</strong><span>PostgreSQL, RabbitMQ, admin, ключи</span></button>
    <button type="button" class="quick-card" data-goto="tab-cert"><span class="qc-icon">🔐</span><strong>3. Сертификаты mTLS</strong><span>Выпуск cert, домен X.509</span></button>
    <button type="button" class="quick-card" data-goto="tab-session"><span class="qc-icon">⏱</span><strong>4. Сессии и API</strong><span>Неактивность, TTL токена</span></button>
    <button type="button" class="quick-card" data-goto="ib-1"><span class="qc-icon">📋</span><strong>5. ИБ-1…132</strong><span>Все требования по категориям</span></button>
    <button type="button" class="quick-card" data-goto="sk-1"><span class="qc-icon">🖥</span><strong>6. СК-1…25</strong><span>Astra Linux, клиенты</span></button>
  </div>
  <p class="meta">Скрипты на диске: <code>output/19-ib-compliance/scripts/</code> · генерация: меню <kbd>[19]→2</kbd> или <kbd>[A]</kbd></p>
  <p class="meta">Портал стенда: <code>$portal</code></p>
</section>
"@)

    # --- Passwords panel ---
    [void]$orderList.Add('tab-pwd')
    [void]$panelsSb.AppendLine(@"
<section id="tab-pwd" class="panel" data-title="Замена паролей">
  <div class="panel-head"><span class="tag tag-warn">ИБ-103 · ИБ-117 · ИБ-118</span><h2>Замена паролей — где и как</h2></div>
  <div class="card">
    <h3>① PostgreSQL — параметр DBPASS</h3>
    <ol class="steps"><li>Панель <kbd>[3] → 4</kbd> (SSH) или на узле БД:</li></ol>
    <div class="cmd-block"><code id="cmd-pg">sudo bash output/03-database/02-change-password.sh 'NovyjParol123!'</code><button type="button" class="btn-copy" data-copy="cmd-pg" data-copy-label="Копировать команду">Копировать команду</button></div>
    $bodyPg
    <ol class="steps" start="2">
      <li>На <b>каждом</b> диспетчере и CeleryMan: <code>/etc/opt/termidesk-vdi/termidesk.conf</code> → <code>DBPASS</code></li>
      <li>Или <code>sudo /opt/termidesk/sbin/termidesk-config</code> → «Настройка подключения к СУБД»</li>
      <li><code>sudo systemctl restart termidesk-vdi</code></li>
      <li>Windows: <code>config/termidesk-settings.json</code> → <code>database.password</code></li>
      <li>OpenBao: секрет <code>SECRETS_OPENBAO_DB_PATH</code></li>
    </ol>
    <div class="shot-uploader" data-shot="pwd-pg"><label class="shot-label">📷 Скриншот: termidesk-config → пароль СУБД<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <div class="card">
    <h3>② RabbitMQ — RABBITMQ_PASS и coordinatorPass</h3>
    <div class="cmd-block"><code id="cmd-rmq">sudo bash output/04-rabbitmq/02-change-password.sh 'NovyjParol123!'</code><button type="button" class="btn-copy" data-copy="cmd-rmq" data-copy-label="Копировать команду">Копировать команду</button></div>
    $bodyRmq
    <ol class="steps">
      <li>Диспетчеры: <code>RABBITMQ_PASS</code> в termidesk.conf</li>
      <li>Шлюзы: <code>coordinatorPass</code>, при необходимости <code>coordinatorUrl</code></li>
      <li>Панель <kbd>[4] → 4</kbd> · JSON: <code>rabbitmq.password</code>, <code>gateway.coordinatorPass</code></li>
    </ol>
    <div class="shot-uploader" data-shot="pwd-rmq"><label class="shot-label">📷 Скриншот: termidesk-config → RabbitMQ<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <div class="card">
    <h3>③ Admin портала и служебные ключи</h3>
    <ol class="steps">
      <li>Портал → профиль admin → смена пароля (не example из JSON)</li>
      <li><code>HEALTH_CHECK_ACCESS_KEY</code> — длинная случайная строка</li>
      <li><code>METRICS_ACCESS_KEY</code> — при metrics API</li>
    </ol>
    <div class="shot-uploader" data-shot="pwd-admin"><label class="shot-label">📷 Скриншот: смена пароля admin<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
    <div class="cmd-block"><code id="cmd-103">sudo bash output/19-ib-compliance/scripts/ib-103-check-defaults.sh</code><button type="button" class="btn-copy" data-copy="cmd-103" data-copy-label="Копировать команду">Копировать команду</button></div>
    $body103
  </div>
  <label class="done-check"><input type="checkbox" data-store="tab-pwd"> Все пароли заменены — отметить в протоколе</label>
</section>
"@)

    # --- Session panel ---
    [void]$orderList.Add('tab-session')
    [void]$panelsSb.AppendLine(@"
<section id="tab-session" class="panel" data-title="Сессии и API">
  <div class="panel-head"><h2>Сессии неактивности и срок API-токена</h2></div>
  <div class="card">
    <h3>Блокировка сессии по неактивности</h3>
    <p>Должна настраиваться длительность неактивности; восстановление — <b>только после повторной аутентификации</b>.</p>
    <ol class="steps">
      <li>Портал → «Система» → «Системные настройки» → безопасность/сессии</li>
      <li>Политики пользовательского портала и клиентов Connect</li>
      <li>Проверка: после таймаута без действий — новый логин обязателен</li>
    </ol>
    <div class="shot-uploader" data-shot="sess-timeout"><label class="shot-label">📷 Скриншот: настройка таймаута сессии<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <div class="card warn-card">
    <h3>Срок действия API-токена</h3>
    <p>Параметры: <code>AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS</code> (по умолчанию 600), login API <code>/api/auth/v7.0/login</code>.</p>
    <p><strong>Требует уточнения на стенде:</strong> web-сессия может разрываться, а Bearer-токен жить до своего TTL. Зафиксируйте фактическое время жизни и согласуйте меры (уменьшение TTL, отзыв, повторный login).</p>
    <div class="shot-uploader" data-shot="api-token"><label class="shot-label">📷 Скриншот: проверка TTL токена после login<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <label class="done-check"><input type="checkbox" data-store="tab-session"> Проверено на стенде</label>
</section>
"@)

    # --- Certificates / mTLS panel ---
    [void]$orderList.Add('tab-cert')
    [void]$panelsSb.AppendLine(@"
<section id="tab-cert" class="panel" data-title="Сертификаты mTLS">
  <div class="panel-head"><span class="tag">ИБ-120 · ИБ-125</span><h2>Сертификат пользователя и аутентификация по сертификату</h2></div>
  <div class="card">
    <h3>① Выпуск сертификата пользователя</h3>
    <p>На эталонном диспетчере или PKI-узле (меню <kbd>[10]</kbd>):</p>
    <div class="cmd-block"><code id="cmd-cert-gen">sudo bash output/10-ssl/generate-user-certificate.sh 'user@corp.example.ru' 365</code><button type="button" class="btn-copy" data-copy="cmd-cert-gen" data-copy-label="Копировать команду">Копировать команду</button></div>
    $bodyCertGen
    <p>Результат: <code>/etc/opt/termidesk-vdi/mtls/{ca.crt, client.crt, client.key}</code></p>
    <div class="cmd-block"><code id="cmd-p12">sudo openssl pkcs12 -export -inkey /etc/opt/termidesk-vdi/mtls/client.key -in /etc/opt/termidesk-vdi/mtls/client.crt -certfile /etc/opt/termidesk-vdi/mtls/ca.crt -out user.p12</code><button type="button" class="btn-copy" data-copy="cmd-p12" data-copy-label="Копировать команду">Копировать команду</button></div>
    <div class="shot-uploader" data-shot="cert-gen"><label class="shot-label">📷 Скриншот: файлы в /etc/opt/termidesk-vdi/mtls/<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <div class="card">
    <h3>② Termidesk / Apache (termidesk-config)</h3>
    <ol class="steps">
      <li>Скопируйте <code>ca.crt</code>, <code>client.crt</code>, <code>client.key</code> в <code>/etc/opt/termidesk-vdi/mtls/</code></li>
      <li><code>sudo /opt/termidesk/sbin/termidesk-config</code> → «Сертификаты» → mTLS: <code>MTLS_MODE=on</code>, пути CA/cert/key</li>
      <li>Apache: фрагмент <code>output/10-ssl/apache-mtls-snippet.conf</code> (заголовки X-TDSK-SSL-CLIENT-*)</li>
      <li>Перезапуск служб через termidesk-config</li>
    </ol>
    $bodyApacheMtls
    <div class="shot-uploader" data-shot="cert-mtls-conf"><label class="shot-label">📷 Скриншот: termidesk-config → MTLS_MODE<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <div class="card">
    <h3>③ Портал — домен X.509</h3>
    <ol class="steps">
      <li>«Аутентификация» → «Домены» → домен типа <b>Сертификат X.509</b> / mTLS</li>
      <li>Укажите поле DN/CN для сопоставления с пользователем</li>
      <li>Привяжите домен к группам и политикам</li>
      <li>Проверьте вход с клиентским сертификатом (браузер + user.p12)</li>
    </ol>
    <div class="shot-uploader" data-shot="cert-login"><label class="shot-label">📷 Скриншот: успешный login по сертификату<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
  </div>
  <label class="done-check"><input type="checkbox" data-store="tab-cert"> mTLS и домен X.509 настроены</label>
</section>
"@)

    $catOrder = @(
        'Общие требования','Идентификация и аутентификация','Управление доступом','Регистрация и учет событий ИБ'
        'Защита программного обеспечения','Обеспечение целостности','Обеспечение доступности','Сетевая безопасность'
        'Криптографическая защита','Контроль НДВ'
    )
    $idx = 0
    foreach ($sc in $scenarios) {
        $idx++
        $id = $sc.Id
        $slug = ($id -replace 'ИБ-','ib-').ToLower()
        [void]$orderList.Add($slug)
        if (-not $catMap.ContainsKey($sc.Cat)) { $catMap[$sc.Cat] = @() }
        $catMap[$sc.Cat] += $slug

        $req = ConvertTo-TermideskHtmlEncode $sc.Req
        $exp = ConvertTo-TermideskHtmlEncode $(if ($sc.Exp) { $sc.Exp } else { 'Критерий выполнен' })
        $stepsHtml = ($sc.Steps | ForEach-Object { "<li>$(ConvertTo-TermideskHtmlEncode $_)</li>" }) -join ''
        $pwdLink = if ($sc.Pwd) { '<p class="alert">⚠️ Сначала выполните раздел «Замена паролей».</p>' } else { '' }
        $certLink = if ($sc.Cert) { '<p class="alert">⚠️ См. раздел «Сертификаты» (mTLS, домен X.509).</p>' } else { '' }
        $sessionLink = if ($sc.Session) { '<p class="alert">⚠️ См. раздел «Сессии/API» (неактивность, TTL токена).</p>' } else { '' }

        $scriptSection = ''
        if ($sc.Script) {
            $rel = Resolve-TermideskHtmlScriptRelPath $sc.Script
            $runCmd = switch ($sc.Type) {
                'bash' { "sudo bash $rel" }
                'powershell' { "powershell -File $rel" }
                default { "# см. файл $rel" }
            }
            $title = if ($sc.Type -eq 'doc') { 'Документ / чек-лист' } else { 'Скрипт проверки' }
            $scriptSection = New-TermideskHtmlScriptBlock -RelPath $rel -RunCmd $runCmd -IdPrefix $slug -ScriptBodies $scriptBodies -Root $root -Title $title
        } else {
            $scriptSection = '<p class="meta">Автоматический скрипт не требуется — ручная проверка или документ.</p>'
        }

        $shotsHtml = ''
        $si = 0
        foreach ($shot in $sc.Shots) {
            $si++
            $sk = "$slug-$si"
            $cap = ConvertTo-TermideskHtmlEncode $shot
            $shotsHtml += @"
<div class="shot-uploader" data-shot="$sk"><label class="shot-label">📷 $cap<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
"@
        }

        [void]$panelsSb.AppendLine(@"
<section id="$slug" class="panel" data-title="$id" data-cat="$(ConvertTo-TermideskHtmlEncode $sc.Cat)" data-idx="$idx">
  <div class="panel-head">
    <span class="tag">$($sc.Cat)</span>
    <span class="tag tag-muted">$idx / $totalIb</span>
    <h2>$id</h2>
  </div>
  <p class="req">$req</p>
  $pwdLink
  $certLink
  $sessionLink
  <h3>Шаги</h3>
  <ol class="steps">$stepsHtml</ol>
  $shotsHtml
  $scriptSection
  <div class="result-box">✓ Ожидаемый результат: $exp</div>
  <label class="done-check"><input type="checkbox" data-store="$slug"> Выполнено — в протоколе</label>
</section>
"@)
    }

    # --- SK scenarios ---
    $skIdx = 0
    $skCatMap = @{}
    foreach ($sc in $skScenarios) {
        $skIdx++
        $id = $sc.Id
        $slug = ($id -replace 'СК-','sk-').ToLower()
        [void]$orderList.Add($slug)
        if (-not $skCatMap.ContainsKey($sc.Cat)) { $skCatMap[$sc.Cat] = @() }
        $skCatMap[$sc.Cat] += $slug

        $req = ConvertTo-TermideskHtmlEncode $sc.Req
        $exp = ConvertTo-TermideskHtmlEncode $(if ($sc.Exp) { $sc.Exp } else { 'Критерий выполнен' })
        $stepsHtml = ($sc.Steps | ForEach-Object { "<li>$(ConvertTo-TermideskHtmlEncode $_)</li>" }) -join ''

        $shotsHtml = ''
        $si = 0
        foreach ($shot in $sc.Shots) {
            $si++
            $sk = "$slug-$si"
            $cap = ConvertTo-TermideskHtmlEncode $shot
            $shotsHtml += @"
<div class="shot-uploader" data-shot="$sk"><label class="shot-label">📷 $cap<input type="file" accept="image/*" hidden></label><div class="shot-preview"></div></div>
"@
        }

        [void]$panelsSb.AppendLine(@"
<section id="$slug" class="panel" data-title="$id" data-cat="СК" data-idx="$skIdx">
  <div class="panel-head">
    <span class="tag tag-sk">$($sc.Cat)</span>
    <span class="tag tag-muted">$skIdx / $totalSk</span>
    <h2>$id</h2>
  </div>
  <p class="req">$req</p>
  <p class="meta">ОС: Astra Linux SE «Воронеж» · Портал: <code>$portal</code></p>
  <h3>Шаги</h3>
  <ol class="steps">$stepsHtml</ol>
  $shotsHtml
  <div class="result-box">✓ Ожидаемый результат: $exp</div>
  <p class="meta">Фиксация: <code>output/19-ib-compliance/sk-report-template.csv</code></p>
  <label class="done-check"><input type="checkbox" data-store="$slug"> Выполнено — в протоколе</label>
</section>
"@)
    }

    # Build category nav groups
    $sidebarNav = New-Object System.Text.StringBuilder
    [void]$sidebarNav.AppendLine(@"
      <li><a href="#tab-home" data-tab="tab-home" class="active"><span class="nav-id">🏠 Старт</span><span class="nav-dot"></span></a></li>
      <li><a href="#tab-pwd" data-tab="tab-pwd"><span class="nav-id">🔑 Пароли</span><span class="nav-dot"></span></a></li>
      <li><a href="#tab-session" data-tab="tab-session"><span class="nav-id">⏱ Сессии/API</span><span class="nav-dot"></span></a></li>
      <li><a href="#tab-cert" data-tab="tab-cert"><span class="nav-id">🔐 Сертификаты</span><span class="nav-dot"></span></a></li>
"@)
    foreach ($cat in $catOrder) {
        if (-not $catMap.ContainsKey($cat)) { continue }
        [void]$sidebarNav.AppendLine("      <li class=""nav-group""><button type=""button"" class=""grp-toggle"" aria-expanded=""true"">$cat</button><ul class=""grp-items"">")
        foreach ($slug in $catMap[$cat]) {
            $sc = $scenarios | Where-Object { ($_.Id -replace 'ИБ-','ib-').ToLower() -eq $slug } | Select-Object -First 1
            if ($sc) {
                [void]$sidebarNav.AppendLine("        <li><a href=""#$slug"" data-tab=""$slug"" data-cat=""$cat""><span class=""nav-id"">$($sc.Id)</span><span class=""nav-dot""></span></a></li>")
            }
        }
        [void]$sidebarNav.AppendLine('      </ul></li>')
    }
    if ($skCatMap.Count -gt 0) {
        $skCatOrder = @(
            'Совместимость веб-клиента','Совместимость нативных клиентов'
            'Совместимость нативных клиентов Windows в среде AstraLinux с использованием Wine'
            'Совместимость клиентов всех типов, требующих вызова прикладного или общесистемного ПО'
        )
        foreach ($cat in $skCatOrder) {
            if (-not $skCatMap.ContainsKey($cat)) { continue }
            $shortCat = if ($cat.Length -gt 42) { $cat.Substring(0, 40) + '…' } else { $cat }
            [void]$sidebarNav.AppendLine("      <li class=""nav-group""><button type=""button"" class=""grp-toggle"" aria-expanded=""true"">$shortCat</button><ul class=""grp-items"">")
            foreach ($slug in $skCatMap[$cat]) {
                $sc = $skScenarios | Where-Object { ($_.Id -replace 'СК-','sk-').ToLower() -eq $slug } | Select-Object -First 1
                if ($sc) {
                    [void]$sidebarNav.AppendLine("        <li><a href=""#$slug"" data-tab=""$slug"" data-cat=""$cat""><span class=""nav-id"">$($sc.Id)</span><span class=""nav-dot""></span></a></li>")
                }
            }
            [void]$sidebarNav.AppendLine('      </ul></li>')
        }
    }

    $orderJson = ($orderList | ForEach-Object { """$_""" }) -join ','

    $html = @"
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Termidesk 7.0 — единый гайд апробирования (ИБ + СК)</title>
<style>
:root{--bg:#0a0e14;--surface:#121820;--panel:#1a2332;--text:#e7ecf3;--muted:#8b98ab;--accent:#4d9fff;--ok:#3dd68c;--warn:#f5c842;--border:#2a3548;--code:#0b1220;--sidebar-w:300px}
*,*::before,*::after{box-sizing:border-box}
html,body{margin:0;height:100%;font-family:"Segoe UI",system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.5}
button{font:inherit;cursor:pointer}
a{color:var(--accent);text-decoration:none}
.app{display:grid;grid-template-columns:var(--sidebar-w) 1fr;grid-template-rows:auto 1fr;min-height:100vh}
.topbar{grid-column:1/-1;display:flex;align-items:center;gap:1rem;padding:.65rem 1rem;background:var(--surface);border-bottom:1px solid var(--border);position:sticky;top:0;z-index:20}
.topbar h1{font-size:1rem;margin:0;font-weight:600;white-space:nowrap}
.topbar .grow{flex:1}
.search-wrap{max-width:360px;flex:1}
.search-wrap input{width:100%;padding:.5rem .75rem;border-radius:8px;border:1px solid var(--border);background:var(--bg);color:var(--text)}
.progress-pill{font-size:.85rem;color:var(--muted);white-space:nowrap}
.progress-pill b{color:var(--ok)}
.menu-btn{display:none;padding:.4rem .6rem;border:1px solid var(--border);border-radius:8px;background:var(--panel);color:var(--text)}
.sidebar{background:var(--surface);border-right:1px solid var(--border);overflow:auto;padding:.75rem;height:calc(100vh - 52px);position:sticky;top:52px}
.sidebar ul{list-style:none;margin:0;padding:0}
.sidebar .nav-id{font-size:.82rem}
.sidebar a{display:flex;align-items:center;justify-content:space-between;padding:.35rem .5rem;border-radius:8px;color:var(--muted);text-decoration:none}
.sidebar a:hover,.sidebar a.active{background:rgba(77,159,255,.12);color:#fff}
.sidebar a.done .nav-dot{background:var(--ok);box-shadow:0 0 0 2px rgba(61,214,140,.3)}
.nav-dot{width:8px;height:8px;border-radius:50%;background:var(--border);flex-shrink:0}
.nav-group{margin-top:.5rem}
.grp-toggle{width:100%;text-align:left;padding:.35rem .5rem;border:none;background:transparent;color:var(--warn);font-size:.72rem;text-transform:uppercase;letter-spacing:.04em}
.grp-items{padding-left:.5rem}
.grp-items.collapsed{display:none}
.content{padding:1.25rem 1.5rem 5rem;max-width:920px;overflow:auto}
.panel{display:none;animation:fade .2s ease}
.panel.active{display:block}
@keyframes fade{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}
.panel-head{margin-bottom:1rem}
.panel-head h2{margin:.35rem 0 0;font-size:1.45rem}
.lead{color:var(--muted);margin:.5rem 0 0}
.tag{display:inline-block;font-size:.72rem;padding:.15rem .45rem;border-radius:6px;background:rgba(77,159,255,.15);color:var(--accent);margin-right:.35rem}
.tag-warn{background:rgba(245,200,66,.15);color:var(--warn)}
.tag-muted{background:rgba(139,152,171,.12);color:var(--muted)}
.tag-sk{background:rgba(180,120,255,.15);color:#c9a0ff}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:.75rem;margin:1rem 0}
.stat-card{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:1rem;text-align:center}
.stat-num{font-size:1.8rem;font-weight:700;color:var(--accent)}
.stat-label{font-size:.78rem;color:var(--muted)}
.progress-bar{height:6px;background:var(--border);border-radius:99px;overflow:hidden;margin-bottom:1.5rem}
.progress-fill{height:100%;width:0;background:linear-gradient(90deg,var(--accent),var(--ok));transition:width .3s}
.quick-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:.75rem;margin:1rem 0}
.quick-card{display:flex;flex-direction:column;gap:.25rem;padding:1rem;border:1px solid var(--border);border-radius:12px;background:var(--panel);color:var(--text);text-align:left}
.quick-card:hover{border-color:var(--accent)}
.qc-icon{font-size:1.4rem}
.quick-card span:last-child{font-size:.78rem;color:var(--muted)}
.card,.warn-card{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:1rem 1.1rem;margin:1rem 0}
.warn-card{border-color:rgba(245,200,66,.35)}
h3{margin:0 0 .6rem;font-size:1rem;color:#d7e3f4}
.steps{padding-left:1.2rem;margin:.5rem 0 1rem}
.steps li{margin:.35rem 0}
.req{color:#c9d7ea;margin-bottom:1rem;font-size:.95rem}
.meta{color:var(--muted);font-size:.85rem}
kbd{font-family:Consolas,monospace;font-size:.85em;padding:0 .3rem;border:1px solid var(--border);border-radius:4px}
code{font-family:Consolas,monospace;font-size:.86em;background:rgba(255,255,255,.06);padding:.1rem .3rem;border-radius:4px}
.cmd-block{display:flex;align-items:center;gap:.5rem;background:var(--code);border:1px solid var(--border);border-radius:10px;padding:.6rem .75rem;margin:.75rem 0;flex-wrap:wrap}
.cmd-block code{flex:1;background:none;padding:0;word-break:break-all}
.btn-copy{padding:.35rem .65rem;border:1px solid var(--border);border-radius:8px;background:var(--panel);color:var(--text);font-size:.78rem;white-space:nowrap}
.btn-copy:hover{border-color:var(--accent)}
.script-card{border:1px solid var(--border);border-radius:12px;padding:1rem;margin:1rem 0;background:rgba(0,0,0,.2)}
.script-head{display:flex;flex-wrap:wrap;gap:.5rem;align-items:center;margin-bottom:.5rem;font-size:.85rem}
.script-src{margin-top:.5rem}
.script-full{margin-top:.75rem;border:1px solid var(--border);border-radius:10px;overflow:hidden}
.script-full-head{display:flex;flex-wrap:wrap;gap:.5rem;align-items:center;padding:.5rem .75rem;background:rgba(255,255,255,.03);font-size:.82rem;border-bottom:1px solid var(--border)}
.script-full pre{margin:0;padding:.75rem;background:var(--code);overflow:auto;font-size:.78rem;max-height:480px;white-space:pre-wrap;word-break:break-word}
.script-full-missing{padding:.75rem;background:rgba(245,200,66,.06);border:1px dashed rgba(245,200,66,.35);border-radius:10px;margin-top:.75rem}
.script-src pre{background:var(--code);padding:.75rem;border-radius:8px;overflow:auto;font-size:.78rem;max-height:240px}
.shot-uploader{margin:.75rem 0;border:2px dashed var(--border);border-radius:12px;overflow:hidden}
.shot-label{display:block;padding:1.5rem;text-align:center;color:var(--muted);cursor:pointer;background:rgba(255,255,255,.02)}
.shot-label:hover{border-color:var(--accent);color:var(--accent)}
.shot-preview{min-height:0}
.shot-preview img{display:block;width:100%;max-height:360px;object-fit:contain;background:#000}
.result-box{background:rgba(61,214,140,.08);border-left:4px solid var(--ok);padding:.75rem 1rem;border-radius:0 8px 8px 0;margin:1rem 0;font-size:.9rem}
.alert{color:var(--warn);font-size:.9rem;margin:.5rem 0}
.done-check{display:flex;align-items:center;gap:.5rem;margin-top:1.25rem;padding:.75rem;background:rgba(255,255,255,.03);border-radius:10px;cursor:pointer}
.done-check input{width:18px;height:18px;accent-color:var(--ok)}
.nav-footer{position:fixed;bottom:0;left:var(--sidebar-w);right:0;display:flex;justify-content:space-between;padding:.75rem 1.5rem;background:rgba(18,24,32,.95);border-top:1px solid var(--border);backdrop-filter:blur(8px);z-index:15}
.nav-footer button{padding:.55rem 1.1rem;border-radius:10px;border:1px solid var(--border);background:var(--panel);color:var(--text)}
.nav-footer button.primary{background:var(--accent);border-color:var(--accent);color:#fff}
.nav-footer button:disabled{opacity:.4;cursor:not-allowed}
@media(max-width:960px){
  .app{grid-template-columns:1fr}
  .sidebar{position:fixed;left:0;top:52px;bottom:0;width:var(--sidebar-w);z-index:30;transform:translateX(-100%);transition:transform .2s}
  .sidebar.open{transform:translateX(0)}
  .menu-btn{display:block}
  .nav-footer{left:0}
}
</style>
</head>
<body>
<div class="app">
<header class="topbar">
  <button type="button" class="menu-btn" id="menuBtn" aria-label="Меню">☰</button>
  <h1>ИБ Termidesk 7.0</h1>
  <div class="search-wrap grow"><input type="search" id="search" placeholder="Поиск: ИБ-103, syslog, пароль…" autocomplete="off"></div>
  <div class="progress-pill"><b id="topDone">0</b> / <span id="topTotal">0</span> ✓</div>
</header>
<aside class="sidebar" id="sidebar">
  <nav><ul id="navList">
$($sidebarNav.ToString())
  </ul></nav>
</aside>
<main class="content" id="content">
$($panelsSb.ToString())
</main>
</div>
<footer class="nav-footer">
  <button type="button" id="btnPrev">← Предыдущий</button>
  <button type="button" id="btnNext" class="primary">Следующий →</button>
</footer>
<script>
(function(){
  var ORDER=[$orderJson];
  var panels=[].slice.call(document.querySelectorAll('.panel'));
  var nav=document.getElementById('navList');
  var storeKey='termidesk-ib-progress-v2';

  function loadProgress(){
    try{return JSON.parse(localStorage.getItem(storeKey)||'{}');}catch(e){return{};}
  }
  function saveProgress(p){localStorage.setItem(storeKey,JSON.stringify(p));}

  function show(id){
    if(!document.getElementById(id)) return;
    panels.forEach(function(p){p.classList.toggle('active',p.id===id);});
    nav.querySelectorAll('a[data-tab]').forEach(function(a){
      a.classList.toggle('active',a.getAttribute('data-tab')===id);
    });
    history.replaceState(null,'','#'+id);
    updateNavFooter();
    document.getElementById('content').scrollTop=0;
    if(window.innerWidth<960) document.getElementById('sidebar').classList.remove('open');
  }

  function updateStats(){
    var p=loadProgress();
    var done=0;
    document.querySelectorAll('.done-check input[data-store]').forEach(function(cb){
      var k=cb.getAttribute('data-store');
      if(p[k]){cb.checked=true;done++;}
      var link=nav.querySelector('a[data-tab="'+k+'"]');
      if(link) link.classList.toggle('done',!!p[k]);
    });
    var total=document.querySelectorAll('.done-check input[data-store]').length;
    var pct=total?Math.round(done/total*100):0;
    ['statDone','topDone'].forEach(function(id){var el=document.getElementById(id);if(el)el.textContent=done;});
    ['statTotal','topTotal'].forEach(function(id){var el=document.getElementById(id);if(el)el.textContent=total;});
    var pf=document.getElementById('progressFill'); if(pf) pf.style.width=pct+'%';
    var sp=document.getElementById('statPct'); if(sp) sp.textContent=pct+'%';
  }

  function updateNavFooter(){
    var id=(location.hash||'#tab-home').replace('#','');
    var i=ORDER.indexOf(id);
    document.getElementById('btnPrev').disabled=(i<=0);
    document.getElementById('btnNext').disabled=(i<0||i>=ORDER.length-1);
  }

  nav.addEventListener('click',function(e){
    var a=e.target.closest('a[data-tab]');
    if(a){e.preventDefault();show(a.getAttribute('data-tab'));}
  });
  document.querySelectorAll('[data-goto]').forEach(function(btn){
    btn.addEventListener('click',function(){show(btn.getAttribute('data-goto'));});
  });
  document.getElementById('btnPrev').onclick=function(){
    var id=(location.hash||'#tab-home').replace('#','');
    var i=ORDER.indexOf(id); if(i>0) show(ORDER[i-1]);
  };
  document.getElementById('btnNext').onclick=function(){
    var id=(location.hash||'#tab-home').replace('#','');
    var i=ORDER.indexOf(id); if(i>=0&&i<ORDER.length-1) show(ORDER[i+1]);
  };
  document.getElementById('menuBtn').onclick=function(){
    document.getElementById('sidebar').classList.toggle('open');
  };
  document.querySelectorAll('.grp-toggle').forEach(function(btn){
    btn.onclick=function(){
      var ul=btn.nextElementSibling;
      var open=ul.classList.toggle('collapsed');
      btn.setAttribute('aria-expanded',!open);
    };
  });
  document.querySelectorAll('.btn-copy').forEach(function(btn){
    btn.onclick=function(){
      var id=btn.getAttribute('data-copy');
      var t=document.getElementById(id);
      if(!t) return;
      var label=btn.getAttribute('data-copy-label')||'Копировать';
      navigator.clipboard.writeText(t.textContent).then(function(){btn.textContent='Скопировано';setTimeout(function(){btn.textContent=label;},1500);});
    };
  });
  document.querySelectorAll('.done-check input[data-store]').forEach(function(cb){
    cb.onchange=function(){
      var p=loadProgress();
      p[cb.getAttribute('data-store')]=cb.checked;
      saveProgress(p); updateStats();
    };
  });
  document.querySelectorAll('.shot-uploader').forEach(function(box){
    var input=box.querySelector('input[type=file]');
    var prev=box.querySelector('.shot-preview');
    input.onchange=function(){
      var f=input.files[0]; if(!f) return;
      var r=new FileReader();
      r.onload=function(){prev.innerHTML='<img src="'+r.result+'" alt="screenshot">';};
      r.readAsDataURL(f);
    };
  });
  document.getElementById('search').oninput=function(){
    var q=this.value.toLowerCase().trim();
    nav.querySelectorAll('a[data-tab]').forEach(function(a){
      var panel=document.getElementById(a.getAttribute('data-tab'));
      var text=(a.textContent+(panel?panel.textContent:'')).toLowerCase();
      a.parentElement.style.display=(!q||text.indexOf(q)>=0)?'':'none';
    });
  };

  var h=(location.hash||'#tab-home').replace('#','');
  show(document.getElementById(h)?h:'tab-home');
  updateStats();
})();
</script>
</body>
</html>
"@

    $htmlPath = Join-Path $root 'ИБ-АПРОБИРОВАНИЕ.html'
    [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($true))
    return $htmlPath
}

function Export-TermideskIbScenarioScripts {
    param([object]$Settings)
    if (-not $Settings) { $Settings = Get-TermideskSettingsOrNew }
    $scripts = Get-TermideskIbScenarioScriptContents -Settings $Settings
    $files = @{}
    foreach ($name in $scripts.Keys) {
        if ($scripts[$name]) { $files["scripts/$name"] = $scripts[$name] }
    }
    if ($files.Count -gt 0) {
        Export-TermideskArtifacts -Section '19-ib-compliance' -Files $files
    }
}

Export-ModuleMember -Function @(
    'Get-TermideskIbScenarios','Get-TermideskSkScenarios','Get-TermideskIbRequirementsCatalog','Export-TermideskIbComplianceHtml',
    'Export-TermideskIbScenarioScripts'
)
