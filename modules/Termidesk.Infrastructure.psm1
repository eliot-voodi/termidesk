# Termidesk 7.0 — инфраструктура (пункты 2–5)

function Get-TermideskSettingsOrNew {
    $s = Read-TermideskSettings
    if ($s) { return $s }
    $example = Join-Path $Script:TermideskConfig 'termidesk-settings.example.json'
    if (Test-Path $example) {
        Copy-Item $example (Get-TermideskConfigPath) -Force
        return Read-TermideskSettings
    }
    throw 'Создайте config/termidesk-settings.json из example.'
}

function Edit-TermideskEnvironmentWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'Подготовка среды'
    $s.environment.domain = Invoke-TermideskPrompt -Caption 'Домен' -Default $s.environment.domain
    $s.environment.ntpServer = Invoke-TermideskPrompt -Caption 'NTP-сервер' -Default $s.environment.ntpServer
    $s.environment.termideskRepo = Invoke-TermideskPrompt -Caption 'Репозиторий Termidesk' -Default $s.environment.termideskRepo
    $s.ssh.user = Invoke-TermideskPrompt -Caption 'SSH-пользователь' -Default $s.ssh.user
    $s.ssh.port = [int](Invoke-TermideskPrompt -Caption 'SSH-порт' -Default ([string]$s.ssh.port))
    Save-TermideskSettings -Settings $s
}

function Export-TermideskPrepareScripts {
    $s = Get-TermideskSettingsOrNew
    $repo = $s.environment.termideskRepo
    $astra = $s.environment.astraRepo
    $ntp = $s.environment.ntpServer

    $prepare = @"
#!/bin/bash
# Termidesk 7.0 — подготовка среды функционирования
set -euo pipefail

echo "=== Обновление системы ==="
sudo apt update && sudo apt upgrade -y

echo "=== Репозиторий Astra Linux ==="
echo '$astra' | sudo tee /etc/apt/sources.list.d/astra-termidesk.list
sudo apt update

echo "=== Синхронизация времени (NTP) ==="
sudo timedatectl set-ntp true
grep -q '$ntp' /etc/systemd/timesyncd.conf 2>/dev/null || echo "NTP=$ntp" | sudo tee -a /etc/systemd/timesyncd.conf
sudo systemctl restart systemd-timesyncd || true

echo "=== Настройка hostname ==="
hostnamectl status

echo "=== Подключение репозитория Termidesk ==="
echo "deb $repo stable main" | sudo tee /etc/apt/sources.list.d/termidesk-vdi.list
sudo apt update

echo "=== Установка termidesk-digsig-keys (ЗПС) ==="
sudo apt install -y termidesk-digsig-keys || echo "Пакет digsig-keys недоступен — пропуск"

echo "=== Проверка портов (firewall) ==="
echo "Откройте порты согласно documentation/termidesk-settings/components-interaction/network-ports.html"

echo "=== Готово ==="
"@

    $firewall = @"
# Рекомендуемые порты Termidesk 7.0
# 443   — Универсальный диспетчер (HTTPS)
# 5432  — PostgreSQL
# 5672  — RabbitMQ AMQP / 15672 management
# 5099  — Termidesk Connect websockify
# 8103  — Celery beat healthcheck
# 8104  — Celery worker healthcheck
# 8200  — OpenBao
"@

    Export-TermideskArtifacts -Section '02-prepare' -Files @{
        '01-prepare-environment.sh' = $prepare
        'firewall-ports.txt'        = $firewall
        'README.txt'                = "Документация: $(Get-TermideskDocLink -Section prepare)"
    }
}

function Edit-TermideskDatabaseWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'PostgreSQL'
    $s.database.clusterMode = Invoke-TermideskPrompt -Caption 'DB_CLUSTER_MODE (single/cluster)' -Default $s.database.clusterMode
    $s.database.host1 = Invoke-TermideskPrompt -Caption 'DBHOST' -Default $s.database.host1
    $s.database.host2 = Invoke-TermideskPrompt -Caption 'DBHOST2' -Default $s.database.host2 -AllowEmpty
    $s.database.host3 = Invoke-TermideskPrompt -Caption 'DBHOST3' -Default $s.database.host3 -AllowEmpty
    $s.database.port = [int](Invoke-TermideskPrompt -Caption 'DBPORT' -Default ([string]$s.database.port))
    $s.database.name = Invoke-TermideskPrompt -Caption 'DBNAME' -Default $s.database.name
    $s.database.user = Invoke-TermideskPrompt -Caption 'DBUSER' -Default $s.database.user
    $s.database.password = Invoke-TermideskPrompt -Caption 'DBPASS' -Secure
    Save-TermideskSettings -Settings $s
    Export-TermideskDatabaseScripts
}

function Export-TermideskDatabaseScripts {
    $s = Get-TermideskSettingsOrNew
    $db = $s.database

    $setup = @"
#!/bin/bash
# Termidesk 7.0 — PostgreSQL
set -euo pipefail
sudo apt update && sudo apt install -y postgresql

sudo su - postgres -c "psql -c \"CREATE DATABASE $($db.name) LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"CREATE USER $($db.user) WITH PASSWORD '$($db.password)';\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $($db.name) TO $($db.user);\""
sudo su - postgres -c "psql -c \"ALTER DATABASE $($db.name) OWNER TO $($db.user);\"" 2>/dev/null || true

# Astra Linux SE — метки безопасности
sudo useradd -M $($db.user) -s /usr/sbin/nologin -d /home/$($db.user) 2>/dev/null || true
sudo pdpl-user -i 0 $($db.user) 2>/dev/null || true
sudo setfacl -m u:postgres:r /etc/parsec/macdb/`$(id -u $($db.user)) 2>/dev/null || true

echo "Настройте listen_addresses и pg_hba.conf для узлов Termidesk"
"@

    $cluster = @"
# Patroni / HAProxy — внешняя настройка кластера PostgreSQL
# Termidesk DB_CLUSTER_MODE=$($db.clusterMode)
DBHOST=$($db.host1)
DBHOST2=$($db.host2)
DBHOST3=$($db.host3)
DBPORT=$($db.port)
"@

    $hba = @"
# pg_hba.conf — пример для Termidesk
host    $($db.name)    $($db.user)    $($db.pgHbaNetwork)    scram-sha-256
"@

    Export-TermideskArtifacts -Section '03-database' -Files @{
        '01-postgresql-setup.sh' = $setup
        'cluster-notes.txt'      = $cluster
        'pg_hba.conf.snippet'    = $hba
        'termidesk.conf.db'      = @"
DB_CLUSTER_MODE='$($db.clusterMode)'
DBHOST='$($db.host1)'
DBHOST2='$($db.host2)'
DBHOST3='$($db.host3)'
DBPORT='$($db.port)'
DBNAME='$($db.name)'
DBUSER='$($db.user)'
"@
    }
}

function Edit-TermideskRabbitMqWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'RabbitMQ / TermideskMQ'
    Write-Host '  [1] RabbitMQ  [2] TermideskMQ' -ForegroundColor Gray
    $type = Read-Host '  Тип брокера'
    $s.rabbitmq.brokerType = if ($type -eq '2') { 'termideskMq' } else { 'rabbitmq' }
    $s.rabbitmq.host = Invoke-TermideskPrompt -Caption 'Хост' -Default $s.rabbitmq.host
    $s.rabbitmq.port = [int](Invoke-TermideskPrompt -Caption 'AMQP порт' -Default ([string]$s.rabbitmq.port))
    $s.rabbitmq.user = Invoke-TermideskPrompt -Caption 'Пользователь' -Default $s.rabbitmq.user
    $s.rabbitmq.password = Invoke-TermideskPrompt -Caption 'Пароль' -Secure
    if ($s.rabbitmq.brokerType -eq 'termideskMq') {
        $s.termideskMq.baseAddress = Invoke-TermideskPrompt -Caption 'TMQ_BASE_ADDRESS' -Default $s.termideskMq.baseAddress
        $s.termideskMq.basePort = [int](Invoke-TermideskPrompt -Caption 'TMQ_BASE_PORT' -Default ([string]$s.termideskMq.basePort))
        $s.termideskMq.clientId = Invoke-TermideskPrompt -Caption 'TMQ_CLIENT_ID' -Default $s.termideskMq.clientId
    }
    Save-TermideskSettings -Settings $s
    Export-TermideskRabbitMqScripts
}

function Export-TermideskRabbitMqScripts {
    $s = Get-TermideskSettingsOrNew
    $rmq = $s.rabbitmq
    $envConf = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'rabbitmq-env.conf.template') -Variables @{ RABBITMQ_PORT = $rmq.port }
    $mainConf = Read-TermideskTemplate 'rabbitmq.conf.template'

    $rabbitScript = @"
#!/bin/bash
set -euo pipefail
sudo apt install -y rabbitmq-server
sudo mkdir -p /etc/rabbitmq
cat <<'EOF' | sudo tee /etc/rabbitmq/rabbitmq.conf
$mainConf
EOF
cat <<'EOF' | sudo tee /etc/rabbitmq/rabbitmq-env.conf
$envConf
EOF
sudo touch /etc/rabbitmq/definitions.json
sudo chown rabbitmq:rabbitmq /etc/rabbitmq/*
sudo rabbitmq-plugins enable rabbitmq_management
cat <<'EOF' | sudo tee -a /etc/sysctl.conf
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
EOF
sudo sysctl -p
sudo systemctl restart rabbitmq-server && sudo systemctl enable rabbitmq-server
echo "Используйте rabbitmq_password2hash.sh для definitions.json"
"@

    $tmqSnippet = @"
# TermideskMQ (экспериментальный, v6.1+)
TMQ_BASE_ADDRESS='$($s.termideskMq.baseAddress)'
TMQ_BASE_PORT='$($s.termideskMq.basePort)'
TMQ_CLIENT_ID='$($s.termideskMq.clientId)'
TMQ_TIMEOUT_AWAIT_SENDING_MESSAGE='$($s.termideskMq.timeoutMs)'
TMQ_PUT_RETRY_COUNT='$($s.termideskMq.retryCount)'
NODE_ROLES='TERMQ'
"@

    Export-TermideskArtifacts -Section '04-rabbitmq' -Files @{
        '01-rabbitmq-setup.sh'   = $rabbitScript
        'termidesk.conf.rabbitmq'= "RABBITMQ_URL='amqp://$($rmq.user):<pass>@$($rmq.host):$($rmq.port)$($rmq.vhost)'"
        'termidesk.conf.tmq'     = $tmqSnippet
        'definitions.json.sample'= @"
{
  "users": [{ "name": "$($rmq.user)", "password_hash": "<hash>", "tags": "administrator" }],
  "vhosts": [{ "name": "$($rmq.vhost)" }],
  "permissions": [{ "user": "$($rmq.user)", "vhost": "$($rmq.vhost)", "configure": ".*", "write": ".*", "read": ".*" }]
}
"@
    }
}

function Edit-TermideskOpenBaoWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'OpenBao'
    $s.openbao.enabled = (Read-Host 'Включить OpenBao? (y/N)') -match '^[yY]'
    if ($s.openbao.enabled) {
        $s.openbao.url = Invoke-TermideskPrompt -Caption 'SECRETS_OPENBAO_URL' -Default $s.openbao.url
        $s.openbao.kvVersion = Invoke-TermideskPrompt -Caption 'KV version (1/2)' -Default $s.openbao.kvVersion
        $s.openbao.roleName = Invoke-TermideskPrompt -Caption 'AppRole name' -Default $s.openbao.roleName
        $s.openbao.roleId = Invoke-TermideskPrompt -Caption 'Role ID' -Default $s.openbao.roleId -AllowEmpty
        $s.openbao.dbPath = Invoke-TermideskPrompt -Caption 'Путь к секретам БД' -Default $s.openbao.dbPath
        $s.openbao.rabbitmqPath = Invoke-TermideskPrompt -Caption 'Путь RabbitMQ' -Default $s.openbao.rabbitmqPath
        $s.cluster.secretsStorage = 'openbao'
    }
    Save-TermideskSettings -Settings $s
    Export-TermideskOpenBaoScripts
}

function Export-TermideskOpenBaoScripts {
    $s = Get-TermideskSettingsOrNew
    $ob = $s.openbao

    $migrate = @"
#!/bin/bash
# Миграция секретов в OpenBao — Termidesk 7.0
set -euo pipefail
sudo sed -i "s/^SECRET_STORAGE_METHOD=.*/SECRET_STORAGE_METHOD='openbao'/" /etc/opt/termidesk-vdi/termidesk.conf
sudo -u termidesk bash -c '/opt/termidesk/sbin/termidesk-vdi-manage tdsk_openbao_migrate'
cd /opt/termidesk/sbin && sudo ./termidesk-config
# Перезапуск служб
sudo systemctl restart termidesk-vdi termidesk-celery-beat termidesk-celery-worker 2>/dev/null || true
"@

    $conf = @"
SECRETS_STORAGE_METHOD='openbao'
SECRETS_OPENBAO_URL='$($ob.url)'
SECRETS_OPENBAO_KV_VERSION='$($ob.kvVersion)'
SECRETS_OPENBAO_TOKEN='$($ob.tokenPath)'
SECRETS_OPENBAO_ROLE_NAME='$($ob.roleName)'
SECRETS_OPENBAO_ROLE_ID='$($ob.roleId)'
SECRETS_OPENBAO_DB_PATH='$($ob.dbPath)'
SECRETS_OPENBAO_RABBITMQ_PATH='$($ob.rabbitmqPath)'
SECRETS_OPENBAO_TERMIDESK_PATH='$($ob.termideskPath)'
SECRETS_OPENBAO_CACHE_LIFETIME='$($ob.cacheLifetime)'
"@

    $reverse = @"
#!/bin/bash
sudo -u termidesk bash -c '/opt/termidesk/sbin/termidesk-vdi-manage tdsk_openbao_reverse_migrate'
sudo sed -i "s/^SECRET_STORAGE_METHOD=.*/SECRET_STORAGE_METHOD='config'/" /etc/opt/termidesk-vdi/termidesk.conf
"@

    Export-TermideskArtifacts -Section '05-openbao' -Files @{
        'termidesk.conf.openbao' = $conf
        'migrate-to-openbao.sh'  = $migrate
        'reverse-migrate.sh'     = $reverse
        'README.txt'             = "OpenBao HA обязателен для отказоустойчивости. Док: $(Get-TermideskDocLink -Section openbao)"
    }
}

function Invoke-TermideskPrepareMenu { Invoke-TermideskSubMenu -Title 'Подготовка среды' -DocSection 'prepare' -Items @{
    '1' = @{ Label = 'Мастер настройки параметров'; Action = { Edit-TermideskEnvironmentWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты подготовки'; Action = { Export-TermideskPrepareScripts } }
    '3' = @{ Label = 'Выполнить на узле (SSH)'; Action = {
        $s = Get-TermideskSettingsOrNew
        Export-TermideskPrepareScripts
        $host_ = Invoke-TermideskPrompt -Caption 'IP целевого узла'
        $script = Get-Content (Get-TermideskOutputPath '02-prepare/01-prepare-environment.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $host_ -ScriptContent $script -ScriptName 'prepare-env.sh'
        Wait-TermideskKey
    }}
}}

function Invoke-TermideskDatabaseMenu { Invoke-TermideskSubMenu -Title 'СУБД PostgreSQL' -DocSection 'prepare' -Items @{
    '1' = @{ Label = 'Мастер настройки БД'; Action = { Edit-TermideskDatabaseWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты'; Action = { Export-TermideskDatabaseScripts } }
    '3' = @{ Label = 'Выполнить установку PostgreSQL (SSH)'; Action = {
        Export-TermideskDatabaseScripts
        $s = Get-TermideskSettingsOrNew
        $script = Get-Content (Get-TermideskOutputPath '03-database/01-postgresql-setup.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $s.database.host1 -ScriptContent $script
        Wait-TermideskKey
    }}
}}

function Invoke-TermideskRabbitMqMenu { Invoke-TermideskSubMenu -Title 'RabbitMQ / TermideskMQ' -DocSection 'prepare' -Items @{
    '1' = @{ Label = 'Мастер настройки брокера'; Action = { Edit-TermideskRabbitMqWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты'; Action = { Export-TermideskRabbitMqScripts } }
    '3' = @{ Label = 'Выполнить установку RabbitMQ (SSH)'; Action = {
        Export-TermideskRabbitMqScripts
        $s = Get-TermideskSettingsOrNew
        $script = Get-Content (Get-TermideskOutputPath '04-rabbitmq/01-rabbitmq-setup.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $s.rabbitmq.host -ScriptContent $script
        Wait-TermideskKey
    }}
}}

function Invoke-TermideskOpenBaoMenu { Invoke-TermideskSubMenu -Title 'OpenBao' -DocSection 'openbao' -Items @{
    '1' = @{ Label = 'Мастер настройки OpenBao'; Action = { Edit-TermideskOpenBaoWizard } }
    '2' = @{ Label = 'Сгенерировать конфигурацию и скрипты'; Action = { Export-TermideskOpenBaoScripts } }
    '3' = @{ Label = 'Миграция секретов в OpenBao (SSH)'; Action = {
        Export-TermideskOpenBaoScripts
        $s = Get-TermideskSettingsOrNew
        $ref = $s.cluster.referenceNode.ip
        if (-not $ref) { $ref = Invoke-TermideskPrompt -Caption 'IP узла Termidesk' }
        $script = Get-Content (Get-TermideskOutputPath '05-openbao/migrate-to-openbao.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $ref -ScriptContent $script
        Wait-TermideskKey
    }}
}}

Export-ModuleMember -Function @(
    'Invoke-TermideskPrepareMenu','Invoke-TermideskDatabaseMenu',
    'Invoke-TermideskRabbitMqMenu','Invoke-TermideskOpenBaoMenu',
    'Export-TermideskPrepareScripts','Export-TermideskDatabaseScripts',
    'Export-TermideskRabbitMqScripts','Export-TermideskOpenBaoScripts'
)
