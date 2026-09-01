# Termidesk 7.0 — пошаговый мастер отказоустойчивого кластера (пункт 18)
# Все параметры вводятся интерактивно, без захардкоженных FQDN/IP/сертификатов

function Get-TermideskHaWizardStatePath {
    Get-TermideskConfigPath -Name 'ha-wizard-state.json'
}

function Read-TermideskHaWizardState {
    try {
        $path = Get-TermideskHaWizardStatePath
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $null }
        Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Save-TermideskHaWizardState {
    param($State)
    Initialize-TermideskPaths
    $json = $State | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText((Get-TermideskHaWizardStatePath), $json, [System.Text.UTF8Encoding]::new($false))
}

function New-TermideskEmptySettings {
    @{
        version = '7.0'
        portal = @{ url = ''; adminUser = ''; adminPassword = ''; verifySsl = $false }
        ssh = @{ user = ''; port = 22; keyPath = '' }
        environment = @{ domain = ''; ntpServer = ''; termideskRepo = ''; astraRepo = '' }
        cluster = @{
            deploymentType = 'standard'
            secretsStorage = 'config'
            referenceNode = @{ name = ''; fqdn = ''; ip = '' }
            dispatchers = @()
            celeryManagers = @()
            gateways = @()
            loadBalancers = @{ fqdn = ''; vip = ''; nodes = @() }
            nginx = @{
                listenHttp = '0.0.0.0:80'
                listenHttps = '0.0.0.0:443 ssl'
                dispatcherPort = 443
                proxyTimeout = 1000
                snippetsDir = '/etc/nginx/snippets'
                sitesAvailableDir = '/etc/nginx/sites-available'
                sitesEnabledDir = '/etc/nginx/sites-enabled'
                sslSnippetCert = 'snippets/ssl-cert.conf'
                sslSnippetParams = 'snippets/ssl-params.conf'
            }
            tls = @{
                mode = 'selfsigned'
                certPath = ''
                keyPath = ''
                dhparamPath = '/etc/nginx/dhparam.pem'
                certDays = 365
                certKeySize = 2048
                certSubject = ''
                sslProtocols = 'TLSv1.3 TLSv1.2'
                sslCiphers = 'ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384'
                sslEcdhCurve = 'secp384r1'
                sslSessionTimeout = '10m'
                sslSessionCacheSize = '10m'
                sslStapling = 'on'
                sslStaplingVerify = 'on'
                dnsResolverPrimary = ''
                dnsResolverSecondary = ''
                dnsResolverValid = 300
                dnsResolverTimeout = 5
            }
        }
        database = @{
            clusterMode = 'cluster'; host1 = ''; host2 = ''; host3 = ''
            port = 5432; name = ''; user = ''; password = ''; pgHbaNetwork = ''
        }
        rabbitmq = @{
            brokerType = 'rabbitmq'; host = ''; port = 5672; managementPort = 15672
            user = ''; password = ''; vhost = '/'; ssl = $false
        }
        openbao = @{ enabled = $false }
        dispatcher = @{ nodeRoles = 'ADMIN,USER'; farmMode = 'dispatcher' }
        celery = @{
            nodeRoles = 'CELERYMAN'; beatHealthCheckPort = 8103; workerHealthCheckPort = 8104
            beatHealthCheckIp = ''; workerHealthCheckIp = ''
            primaryCheckInterval = 3; primaryLockTimeout = 45
        }
        gateway = @{
            coordinatorUrl = ''; coordinatorUser = ''; coordinatorPass = ''
            coordinatorTimeout = 30; coordinatorRefreshTime = 60
            healthCheckPath = '/api/health'; listenPort = 5099
        }
        monitoring = @{ healthCheckAccessKey = ''; metricsAccessKey = '' }
    } | ConvertTo-Json -Depth 8 | ConvertFrom-Json
}

function Invoke-TermideskHaWizardCollectParameters {
    Show-TermideskBanner
    Write-Host '  Пошаговый сбор параметров HA-кластера' -ForegroundColor Yellow
    Write-Host '  Все поля вводятся вручную — значения по умолчанию не подставляются.' -ForegroundColor DarkGray
    Write-Host ''

    Write-Host '  Тип развёртывания:' -ForegroundColor Cyan
    Write-Host '    [1] Стандартный (диспетчеры и CeleryMan на отдельных узлах)'
    Write-Host '    [2] Минимальный (CeleryMan на узлах диспетчеров)'
    $depType = Read-Host '  Выбор'
    $deploymentType = if ($depType -eq '2') { 'minimal' } else { 'standard' }

    $totalSteps = if ($deploymentType -eq 'standard') { 12 } else { 11 }
    $step = 0

    $s = New-TermideskEmptySettings
    $s.cluster.deploymentType = $deploymentType

    # --- Шаг 1: Общие ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Общие параметры инфраструктуры'
    $s.environment.domain = Invoke-TermideskPromptRequired -Caption 'DNS-домен инфраструктуры' -Hint 'Например: corp.example.ru'
    $s.environment.ntpServer = Invoke-TermideskPromptRequired -Caption 'NTP-сервер синхронизации времени'
    $s.environment.termideskRepo = Invoke-TermideskPromptRequired -Caption 'URL репозитория Termidesk (deb ...)'
    $s.environment.astraRepo = Invoke-TermideskPromptOptional -Caption 'Строка репозитория Astra Linux (необяз.)'

    # --- Шаг 2: SSH ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'SSH-доступ к узлам Linux'
    $s.ssh.user = Invoke-TermideskPromptRequired -Caption 'SSH-пользователь'
    $s.ssh.port = [int](Invoke-TermideskPromptRequired -Caption 'SSH-порт')
    $s.ssh.keyPath = Invoke-TermideskPromptOptional -Caption 'Путь к приватному SSH-ключу (необяз.)'

    # --- Шаг 3: PostgreSQL ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Кластер PostgreSQL'
    Write-Host '  DB_CLUSTER_MODE=cluster — Termidesk последовательно обращается к узлам до подключения к master.' -ForegroundColor DarkGray
    $s.database.clusterMode = Invoke-TermideskPromptRequired -Caption 'DB_CLUSTER_MODE (single/cluster)'
    $s.database.host1 = Invoke-TermideskPromptRequired -Caption 'DBHOST — узел 1 (IP или FQDN)'
    $s.database.host2 = Invoke-TermideskPromptOptional -Caption 'DBHOST2 — узел 2 (необяз.)'
    $s.database.host3 = Invoke-TermideskPromptOptional -Caption 'DBHOST3 — узел 3 (необяз.)'
    $s.database.port = [int](Invoke-TermideskPromptRequired -Caption 'DBPORT')
    $s.database.name = Invoke-TermideskPromptRequired -Caption 'DBNAME'
    $s.database.user = Invoke-TermideskPromptRequired -Caption 'DBUSER'
    $s.database.password = Invoke-TermideskPromptRequired -Caption 'DBPASS' -Secure
    $s.database.pgHbaNetwork = Invoke-TermideskPromptRequired -Caption 'Сеть для pg_hba.conf (CIDR)' -Hint 'Например: 10.10.0.0/24'

    # --- Шаг 4: RabbitMQ ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Брокер сообщений'
    Write-Host '  [1] RabbitMQ  [2] TermideskMQ (экспериментальный)' -ForegroundColor DarkGray
    $brokerChoice = Read-Host '  Тип брокера'
    $s.rabbitmq.brokerType = if ($brokerChoice -eq '2') { 'termideskMq' } else { 'rabbitmq' }
    $s.rabbitmq.host = Invoke-TermideskPromptRequired -Caption 'Хост брокера (IP или FQDN)'
    $s.rabbitmq.port = [int](Invoke-TermideskPromptRequired -Caption 'Порт AMQP')
    $mgmtRaw = Invoke-TermideskPromptOptional -Caption 'Порт management UI (необяз., Enter=15672)'
    $s.rabbitmq.managementPort = if ([string]::IsNullOrWhiteSpace($mgmtRaw)) { 15672 } else { [int]$mgmtRaw }
    $s.rabbitmq.user = Invoke-TermideskPromptRequired -Caption 'Пользователь брокера'
    $s.rabbitmq.password = Invoke-TermideskPromptRequired -Caption 'Пароль брокера' -Secure
    $s.rabbitmq.vhost = Invoke-TermideskPromptRequired -Caption 'Virtual host'

    # --- Шаг 5: OpenBao (опционально) ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Хранилище секретов OpenBao'
    $useOpenBao = (Read-Host '  Использовать OpenBao для паролей? (y/N)') -match '^[yYдД]'
    if ($useOpenBao) {
        $s.openbao.enabled = $true
        $s.cluster.secretsStorage = 'openbao'
        $s.openbao | Add-Member -NotePropertyName url -NotePropertyValue (Invoke-TermideskPromptRequired -Caption 'SECRETS_OPENBAO_URL') -Force
        $s.openbao | Add-Member -NotePropertyName kvVersion -NotePropertyValue (Invoke-TermideskPromptRequired -Caption 'KV version (1/2)') -Force
        $s.openbao | Add-Member -NotePropertyName roleName -NotePropertyValue (Invoke-TermideskPromptRequired -Caption 'AppRole name') -Force
        $s.openbao | Add-Member -NotePropertyName roleId -NotePropertyValue (Invoke-TermideskPromptRequired -Caption 'Role ID') -Force
        $s.openbao | Add-Member -NotePropertyName dbPath -NotePropertyValue (Invoke-TermideskPromptRequired -Caption 'Путь секретов БД') -Force
        $s.openbao | Add-Member -NotePropertyName rabbitmqPath -NotePropertyValue (Invoke-TermideskPromptRequired -Caption 'Путь секретов RabbitMQ') -Force
    }

    # --- Шаг 6: TLS/SSL ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'TLS/SSL для балансировщика'
    Write-Host '  [1] Сгенерировать самоподписанный сертификат  [2] Использовать существующие файлы' -ForegroundColor DarkGray
    Write-Host '  Пути указывайте КАК НА LINUX-УЗЛЕ балансировщика (например /etc/ssl/certs/...), не пути Windows.' -ForegroundColor Yellow
    $tlsMode = Read-Host '  Режим'
    $s.cluster.tls.mode = if ($tlsMode -eq '2') { 'provided' } else { 'selfsigned' }
    $s.cluster.tls.certPath = Invoke-TermideskPromptRequired -Caption 'Путь к SSL-сертификату на балансировщике' -Hint 'Linux-путь, напр. /etc/ssl/certs/portal.crt'
    $s.cluster.tls.keyPath = Invoke-TermideskPromptRequired -Caption 'Путь к закрытому ключу SSL' -Hint 'Linux-путь, напр. /etc/ssl/private/portal.key'
    $s.cluster.tls.dhparamPath = Invoke-TermideskPromptRequired -Caption 'Путь к dhparam.pem' -Hint 'Файл параметров Diffie-Hellman для nginx (ssl_dhparam). Обычно: /etc/nginx/dhparam.pem — если файла ещё нет, укажите этот путь и создайте его на LB: sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096'
    if ($s.cluster.tls.mode -eq 'selfsigned') {
        $s.cluster.tls.certDays = [int](Invoke-TermideskPromptRequired -Caption 'Срок действия сертификата (дней)')
        $s.cluster.tls.certKeySize = [int](Invoke-TermideskPromptRequired -Caption 'Размер RSA-ключа (бит)')
        $s.cluster.tls.certSubject = Invoke-TermideskPromptRequired -Caption 'Subject CN (Common Name)' -Hint 'Обычно FQDN VIP портала'
    }
    $s.cluster.tls.dnsResolverPrimary = Invoke-TermideskPromptRequired -Caption 'DNS resolver primary (для nginx ssl_stapling)'
    $s.cluster.tls.dnsResolverSecondary = Invoke-TermideskPromptOptional -Caption 'DNS resolver secondary (необяз.)'

    # --- Шаг 7: Диспетчеры ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Универсальные диспетчеры'
    $dispCount = Invoke-TermideskPromptInt -Caption 'Количество диспетчеров (мин. 2)' -Minimum 2 -Maximum 32
    $s.dispatcher.nodeRoles = Invoke-TermideskPromptRequired -Caption 'NODE_ROLES для диспетчеров' -Hint 'ADMIN,USER или ADMIN,USER,CELERYMAN для minimal'
    $dispatchers = @()
    for ($i = 1; $i -le $dispCount; $i++) {
        $dispatchers += Invoke-TermideskPromptNode -RoleLabel 'Диспетчер' -Index $i -MarkReference:($i -eq 1)
    }
    $s.cluster.dispatchers = $dispatchers
    $ref = $dispatchers | Where-Object { $_.isReference } | Select-Object -First 1
    $s.cluster.referenceNode = @{ name = $ref.name; fqdn = $ref.fqdn; ip = $ref.ip }
    $s.dispatcher.nodeName = $ref.name
    $s.portal.url = Invoke-TermideskPromptRequired -Caption 'URL портала администратора (https://...)' -Hint "Можно указать https://$($ref.fqdn)"
    $s.portal.adminUser = Invoke-TermideskPromptRequired -Caption 'Логин администратора Termidesk'
    $s.portal.adminPassword = Invoke-TermideskPromptRequired -Caption 'Пароль администратора' -Secure

    # --- Шаг 8: CeleryMan ---
    if ($deploymentType -eq 'standard') {
        $step++
        Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Менеджеры рабочих мест (CeleryMan)'
        $celeryCount = Invoke-TermideskPromptInt -Caption 'Количество узлов CeleryMan (мин. 2)' -Minimum 2 -Maximum 32
        $celeryNodes = @()
        for ($i = 1; $i -le $celeryCount; $i++) {
            $celeryNodes += Invoke-TermideskPromptNode -RoleLabel 'CeleryMan' -Index $i
        }
        $s.cluster.celeryManagers = $celeryNodes
        $s.celery.beatHealthCheckPort = [int](Invoke-TermideskPromptRequired -Caption 'CELERY_BEAT_HEALTH_CHECK_PORT')
        $s.celery.workerHealthCheckPort = [int](Invoke-TermideskPromptRequired -Caption 'CELERY_WORKER_HEALTH_CHECK_PORT')
    }

    # --- Шаг 9: Шлюзы ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Termidesk Connect (Шлюзы)'
    $gwCount = Invoke-TermideskPromptInt -Caption 'Количество шлюзов (мин. 2)' -Minimum 2 -Maximum 32
    $gateways = @()
    for ($i = 1; $i -le $gwCount; $i++) {
        $gw = Invoke-TermideskPromptNode -RoleLabel 'Шлюз' -Index $i
        $gw | Add-Member -NotePropertyName port -NotePropertyValue ([int](Invoke-TermideskPromptRequired -Caption '  Порт websockify')) -Force
        $gateways += $gw
    }
    $s.cluster.gateways = $gateways
    $s.gateway.coordinatorUrl = Invoke-TermideskPromptRequired -Caption 'coordinatorUrl (amqp://...)' 
    $s.gateway.coordinatorUser = Invoke-TermideskPromptRequired -Caption 'coordinatorUser'
    $s.gateway.coordinatorPass = Invoke-TermideskPromptRequired -Caption 'coordinatorPass' -Secure
    $s.gateway.healthCheckPath = Invoke-TermideskPromptRequired -Caption 'healthCheckPath'

    # --- Шаг 10: Балансировщики ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Балансировщики нагрузки (nginx)'
    $s.cluster.loadBalancers.fqdn = Invoke-TermideskPromptRequired -Caption 'FQDN VIP портала (для пользователей)'
    $s.cluster.loadBalancers.vip = Invoke-TermideskPromptOptional -Caption 'VIP IP (необяз., если отличается от FQDN)'
    $lbCount = Invoke-TermideskPromptInt -Caption 'Количество узлов балансировщика (мин. 1)' -Minimum 1 -Maximum 16
    $lbNodes = @()
    for ($i = 1; $i -le $lbCount; $i++) {
        $lbNodes += Invoke-TermideskPromptNode -RoleLabel 'Балансировщик' -Index $i
    }
    $s.cluster.loadBalancers.nodes = $lbNodes
    $s.cluster.nginx.listenHttp = Invoke-TermideskPromptRequired -Caption 'listen HTTP (nginx)' -Hint '0.0.0.0:80'
    $s.cluster.nginx.listenHttps = Invoke-TermideskPromptRequired -Caption 'listen HTTPS (nginx)' -Hint '0.0.0.0:443 ssl'
    $s.cluster.nginx.dispatcherPort = [int](Invoke-TermideskPromptRequired -Caption 'Порт HTTPS диспетчеров')
    $s.cluster.nginx.proxyTimeout = [int](Invoke-TermideskPromptRequired -Caption 'proxy timeout (сек)')
    $s.cluster.nginx.snippetsDir = Invoke-TermideskPromptRequired -Caption 'Каталог nginx snippets'
    $s.cluster.nginx.sslSnippetCert = Invoke-TermideskPromptRequired -Caption 'Include-путь ssl-cert snippet'
    $s.cluster.nginx.sslSnippetParams = Invoke-TermideskPromptRequired -Caption 'Include-путь ssl-params snippet'

    # --- Шаг 11: Health Check ---
    $step++
    Show-TermideskStepHeader -Step $step -Total $totalSteps -Title 'Мониторинг и Health Check'
    $s.monitoring.healthCheckAccessKey = Invoke-TermideskPromptRequired -Caption 'HEALTH_CHECK_ACCESS_KEY'
    $s.monitoring.metricsAccessKey = Invoke-TermideskPromptOptional -Caption 'METRICS_ACCESS_KEY (необяз.)'

    # --- Сводка ---
    Show-TermideskBanner
    Write-Host '  Сводка конфигурации HA-кластера' -ForegroundColor Yellow
    Write-Host "  Тип: $($s.cluster.deploymentType) | Домен: $($s.environment.domain)" -ForegroundColor Gray
    Write-Host "  PostgreSQL: $($s.database.host1)$(if($s.database.host2){", $($s.database.host2)"})$(if($s.database.host3){", $($s.database.host3)"}) :$($s.database.port)"
    Write-Host "  RabbitMQ: $($s.rabbitmq.host):$($s.rabbitmq.port)"
    Write-Host "  Диспетчеры: $($s.cluster.dispatchers.Count) | Шлюзы: $($s.cluster.gateways.Count) | LB: $($s.cluster.loadBalancers.nodes.Count)"
    Write-Host "  VIP: $($s.cluster.loadBalancers.fqdn)"
    Write-Host "  SSL cert: $($s.cluster.tls.certPath)"
    Write-Host ''

    if (-not (Confirm-TermideskAction -Message 'Сохранить конфигурацию и сгенерировать скрипты?')) {
        Write-Host 'Отменено.' -ForegroundColor Yellow
        return $null
    }

    Save-TermideskSettings -Settings $s
    Save-TermideskHaWizardState -State @{ phase = 'configured'; completedSteps = @(); lastUpdated = (Get-Date -Format 'o') }
    Export-TermideskHaWizardArtifacts -Settings $s
    Write-Host ''
    Write-Host 'Конфигурация сохранена. Перейдите к пошаговому развёртыванию.' -ForegroundColor Green
    Wait-TermideskKey
    return $s
}

function Get-TermideskHaDeploySteps {
    param([string]$DeploymentType = 'standard')
    $steps = [ordered]@{
        '1'  = @{ Id = 'prepare';    Label = 'Подготовка среды (NTP, репозитории)'; Script = '01-prepare-environment.sh'; Section = '18-ha-wizard' }
        '2'  = @{ Id = 'postgres';   Label = 'PostgreSQL'; Script = '02-postgresql-setup.sh'; Section = '18-ha-wizard' }
        '3'  = @{ Id = 'rabbitmq';   Label = 'RabbitMQ'; Script = '03-rabbitmq-setup.sh'; Section = '18-ha-wizard' }
        '4'  = @{ Id = 'dispatcher'; Label = 'Первый диспетчер (эталон)'; Script = '04-dispatcher-reference.sh'; Section = '18-ha-wizard'; IsGuide = $true }
        '5'  = @{ Id = 'dispatchers'; Label = 'Дополнительные диспетчеры'; Script = '05-dispatcher-additional.sh'; Section = '18-ha-wizard'; IsGuide = $true }
    }
    if ($DeploymentType -eq 'standard') {
        $steps['6'] = @{ Id = 'celery'; Label = 'Менеджеры рабочих мест'; Script = '06-celery-setup.sh'; Section = '18-ha-wizard' }
        $steps['7'] = @{ Id = 'gateway'; Label = 'Termidesk Connect (шлюзы)'; Script = '07-gateway-setup.sh'; Section = '18-ha-wizard'; IsGuide = $true }
        $steps['8'] = @{ Id = 'nginx'; Label = 'Балансировщик nginx'; Script = '08-nginx-lb-setup.sh'; Section = '18-ha-wizard' }
        $steps['9'] = @{ Id = 'verify'; Label = 'Проверка кластера'; Script = '09-healthcheck.ps1'; Section = '18-ha-wizard' }
    }
    else {
        $steps['6'] = @{ Id = 'gateway'; Label = 'Termidesk Connect (шлюзы)'; Script = '07-gateway-setup.sh'; Section = '18-ha-wizard'; IsGuide = $true }
        $steps['7'] = @{ Id = 'nginx'; Label = 'Балансировщик nginx'; Script = '08-nginx-lb-setup.sh'; Section = '18-ha-wizard' }
        $steps['8'] = @{ Id = 'verify'; Label = 'Проверка кластера'; Script = '09-healthcheck.ps1'; Section = '18-ha-wizard' }
    }
    return $steps
}

function Export-TermideskHaWizardArtifacts {
    param($Settings)
    if (-not $Settings) { $Settings = Read-TermideskSettings }
    if (-not $Settings) { throw 'Нет сохранённой конфигурации. Запустите сбор параметров.' }

    $s = $Settings
    $db = $s.database
    $rmq = $s.rabbitmq
    $tls = $s.cluster.tls
    $ngx = $s.cluster.nginx
    $sshUser = $s.ssh.user
    $ref = $s.cluster.referenceNode

    $prepare = @"
#!/bin/bash
set -euo pipefail
echo "=== NTP: $($s.environment.ntpServer) ==="
grep -q '$($s.environment.ntpServer)' /etc/systemd/timesyncd.conf 2>/dev/null || echo "NTP=$($s.environment.ntpServer)" | sudo tee -a /etc/systemd/timesyncd.conf
sudo systemctl restart systemd-timesyncd || true
echo "deb $($s.environment.termideskRepo) stable main" | sudo tee /etc/apt/sources.list.d/termidesk-vdi.list
$(if ($s.environment.astraRepo) { "echo '$($s.environment.astraRepo)' | sudo tee /etc/apt/sources.list.d/astra.list" })
sudo apt update
"@

    $postgres = @"
#!/bin/bash
set -euo pipefail
sudo apt install -y postgresql
sudo su - postgres -c "psql -c \"CREATE DATABASE $($db.name) LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"CREATE USER $($db.user) WITH PASSWORD '$($db.password)';\"" 2>/dev/null || true
sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $($db.name) TO $($db.user);\""
sudo su - postgres -c "psql -c \"ALTER DATABASE $($db.name) OWNER TO $($db.user);\"" 2>/dev/null || true
echo "# pg_hba: host $($db.name) $($db.user) $($db.pgHbaNetwork) scram-sha-256"
"@

    $envConf = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'rabbitmq-env.conf.template') -Variables @{ RABBITMQ_PORT = $rmq.port }
    $rabbit = @"
#!/bin/bash
set -euo pipefail
sudo apt install -y rabbitmq-server
sudo mkdir -p /etc/rabbitmq
cat <<'EOF' | sudo tee /etc/rabbitmq/rabbitmq.conf
$(Read-TermideskTemplate 'rabbitmq.conf.template')
EOF
cat <<'EOF' | sudo tee /etc/rabbitmq/rabbitmq-env.conf
$envConf
EOF
sudo rabbitmq-plugins enable rabbitmq_management
sudo systemctl restart rabbitmq-server
"@

    $dispRef = @"
#!/bin/bash
# Эталонный диспетчер: $($ref.fqdn) ($($ref.ip))
# NODE_NAME=$($ref.name) | NODE_ROLES=$($s.dispatcher.nodeRoles)
sudo apt install -y termidesk-vdi
cd /opt/termidesk/sbin && sudo ./termidesk-config
# DB: $($db.host1):$($db.port)/$($db.name) user=$($db.user)
# RABBITMQ: $($rmq.host):$($rmq.port)$($rmq.vhost)
sudo scp -r /etc/opt/termidesk-vdi ${sshUser}@<target>:/home/${sshUser}/
"@

    $dispAdd = @"
# Дополнительные диспетчеры
$($s.cluster.dispatchers | Where-Object { -not $_.isReference } | ForEach-Object {
"--- $($_.name) $($_.fqdn) ($($_.ip)) ---
ssh ${sshUser}@$($_.ip) 'sudo mv /home/${sshUser}/termidesk-vdi /etc/opt/'
sudo apt install -y termidesk-vdi  # те же параметры БД/RabbitMQ
"
} | Out-String)
"@

    $celeryScript = if ($s.cluster.deploymentType -eq 'standard') {
        $local = Read-TermideskTemplate 'termidesk-vdi.local.template'
        @"
#!/bin/bash
set -euo pipefail
sudo mv /home/${sshUser}/termidesk-vdi /etc/opt/
cat <<'EOF' | sudo tee /etc/default/termidesk-vdi.local
$local
EOF
sudo sed -i "s/^NODE_ROLES=.*/NODE_ROLES='$($s.celery.nodeRoles)'/" /etc/opt/termidesk-vdi/termidesk.conf
sudo apt -y install termidesk-vdi
"@
    } else { '# CeleryMan включён в NODE_ROLES диспетчеров (minimal)' }

    $gatewayScript = @"
# Termidesk Connect — шлюзы
$($s.cluster.gateways | ForEach-Object {
"[$($_.name)] $($_.fqdn) $($_.ip):$($_.port)
coordinatorUrl: $($s.gateway.coordinatorUrl)
coordinatorUser: $($s.gateway.coordinatorUser)
healthCheckPath: $($s.gateway.healthCheckPath)
"
} | Out-String)
"@

    $gwUpstreams = ($s.cluster.gateways | ForEach-Object { "     server $($_.ip):$($_.port);" }) -join "`n"
    $dispUpstreams = ($s.cluster.dispatchers | ForEach-Object { "     server $($_.ip):$($ngx.dispatcherPort);" }) -join "`n"
    $siteConf = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'nginx-site.conf.template') -Variables @{
        GATEWAY_UPSTREAMS = $gwUpstreams; DISPATCHER_UPSTREAMS = $dispUpstreams
        LISTEN_HTTP = $ngx.listenHttp; LISTEN_HTTPS = $ngx.listenHttps
        SSL_SNIPPET_CERT = $ngx.sslSnippetCert; SSL_SNIPPET_PARAMS = $ngx.sslSnippetParams
        PROXY_TIMEOUT = $ngx.proxyTimeout
    }
    $sslCertSnippet = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'nginx-ssl-cert.conf.template') -Variables @{
        SSL_CERT_PATH = $tls.certPath; SSL_KEY_PATH = $tls.keyPath
    }
    $sslParamsSnippet = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'nginx-ssl-params.conf.template') -Variables @{
        SSL_PROTOCOLS = $tls.sslProtocols; DHPARAM_PATH = $tls.dhparamPath
        SSL_CIPHERS = $tls.sslCiphers; SSL_ECDH_CURVE = $tls.sslEcdhCurve
        SSL_SESSION_TIMEOUT = $tls.sslSessionTimeout; SSL_SESSION_CACHE_SIZE = $tls.sslSessionCacheSize
        SSL_STAPLING = $tls.sslStapling; SSL_STAPLING_VERIFY = $tls.sslStaplingVerify
        DNS_RESOLVER_PRIMARY = $tls.dnsResolverPrimary
        DNS_RESOLVER_SECONDARY = if ($tls.dnsResolverSecondary) { $tls.dnsResolverSecondary } else { '' }
        DNS_RESOLVER_VALID = $tls.dnsResolverValid; DNS_RESOLVER_TIMEOUT = $tls.dnsResolverTimeout
    }

    $certGen = if ($tls.mode -eq 'selfsigned') {
@"
sudo openssl req -new -x509 -nodes -days $($tls.certDays) -newkey rsa:$($tls.certKeySize) \
  -keyout $($tls.keyPath) -out $($tls.certPath) -subj "/CN=$($tls.certSubject)"
sudo openssl dhparam -out $($tls.dhparamPath) 4096
"@
    } else {
@"
echo 'Используются предоставленные сертификаты: $($tls.certPath)'
if [ ! -f '$($tls.dhparamPath)' ]; then
  echo "=== Генерация dhparam (это может занять несколько минут) ==="
  sudo openssl dhparam -out $($tls.dhparamPath) 4096
fi
"@
    }

    $nginxScript = @"
#!/bin/bash
set -euo pipefail
FQDN="$($s.cluster.loadBalancers.fqdn)"
sudo apt install -y nginx openssl
$certGen
sudo mkdir -p $($ngx.snippetsDir)
cat <<'CERT' | sudo tee $($ngx.snippetsDir)/ssl-cert.conf
$sslCertSnippet
CERT
cat <<'PARAMS' | sudo tee $($ngx.snippetsDir)/ssl-params.conf
$sslParamsSnippet
PARAMS
cat <<'SITE' | sudo tee $($ngx.sitesAvailableDir)/`${FQDN}.conf
$siteConf
SITE
sudo ln -sf $($ngx.sitesAvailableDir)/`${FQDN}.conf $($ngx.sitesEnabledDir)/
sudo nginx -t && sudo systemctl restart nginx
"@

    $confSnippet = @"
TERMIDESK_FARM_MODE='$($s.dispatcher.farmMode)'
DB_CLUSTER_MODE='$($db.clusterMode)'
DBHOST='$($db.host1)' DBHOST2='$($db.host2)' DBHOST3='$($db.host3)'
DBPORT='$($db.port)' DBNAME='$($db.name)' DBUSER='$($db.user)'
RABBITMQ_URL='amqp://$($rmq.user):***@$($rmq.host):$($rmq.port)$($rmq.vhost)'
SECRETS_STORAGE_METHOD='$($s.cluster.secretsStorage)'
HEALTH_CHECK_ACCESS_KEY='$($s.monitoring.healthCheckAccessKey)'
"@

    $healthScript = New-TermideskHealthCheckScriptFromSettings -Settings $s

    $readme = @"
Пошаговое развёртывание HA-кластера Termidesk 7.0
Домен: $($s.environment.domain)
VIP: $($s.cluster.loadBalancers.fqdn)
Эталон: $($ref.fqdn)

1. 01-prepare-environment.sh  -> инфраструктурные узлы
2. 02-postgresql-setup.sh     -> $($db.host1)
3. 03-rabbitmq-setup.sh       -> $($rmq.host)
4. 04-dispatcher-reference.sh -> $($ref.ip)
5. 05-dispatcher-additional   -> остальные диспетчеры
$(if ($s.cluster.deploymentType -eq 'standard') { "6. 06-celery-setup.sh -> узлы CeleryMan`n7. 07-gateway-setup -> шлюзы`n8. 08-nginx-lb-setup.sh -> LB`n9. 09-healthcheck.ps1" } else { "6. 07-gateway -> шлюзы`n7. 08-nginx -> LB`n8. 09-healthcheck.ps1" })
"@

    Export-TermideskArtifacts -Section '18-ha-wizard' -Files @{
        '01-prepare-environment.sh'    = $prepare
        '02-postgresql-setup.sh'       = $postgres
        '03-rabbitmq-setup.sh'           = $rabbit
        '04-dispatcher-reference.sh'     = $dispRef
        '05-dispatcher-additional.sh'    = $dispAdd
        '06-celery-setup.sh'             = $celeryScript
        '07-gateway-setup.sh'            = $gatewayScript
        '08-nginx-lb-setup.sh'           = $nginxScript
        '09-healthcheck.ps1'             = $healthScript
        'termidesk.conf.snippet'         = $confSnippet
        'nginx-site.conf'                = $siteConf
        'README-deploy-order.txt'        = $readme
    }
}

function New-TermideskHealthCheckScriptFromSettings {
    param($Settings)
    $lines = @()
    foreach ($d in $Settings.cluster.dispatchers) { $lines += "Test-Node '$($d.ip)' '$($d.name) dispatcher'" }
    foreach ($c in $Settings.cluster.celeryManagers) { $lines += "Test-Node '$($c.ip)' '$($c.name) celery'" }
    foreach ($g in $Settings.cluster.gateways) { $lines += "Test-Node '$($g.ip)' '$($g.name) gateway'" }
    foreach ($lb in $Settings.cluster.loadBalancers.nodes) { $lines += "Test-Node '$($lb.ip)' '$($lb.name) lb'" }
    $lines += "Test-Node '$($Settings.database.host1)' 'PostgreSQL'"
    $lines += "Test-Node '$($Settings.rabbitmq.host)' 'RabbitMQ'"
    $block = ($lines | Select-Object -Unique) -join "`n"
    @"
param()
function Test-Node { param([string]`$Ip,[string]`$Label)
  Write-Host -NoNewline "  `$Label (`$Ip): "
  if (Test-Connection `$Ip -Count 1 -Quiet -EA SilentlyContinue) { Write-Host OK -ForegroundColor Green } else { Write-Host FAIL -ForegroundColor Red }
}
Write-Host '=== HA Cluster Health Check ===' -ForegroundColor Cyan
$block
Write-Host "VIP: https://$($Settings.cluster.loadBalancers.fqdn)"
"@
}

function Invoke-TermideskHaDeployStepInteractive {
    param([string]$StepKey)

    $s = Read-TermideskSettings
    if (-not $s) {
        Write-Host 'Сначала выполните сбор параметров [1].' -ForegroundColor Red
        Wait-TermideskKey
        return
    }

    $steps = Get-TermideskHaDeploySteps -DeploymentType $s.cluster.deploymentType
    if (-not $steps.Contains($StepKey)) {
        Write-Host 'Неизвестный шаг.' -ForegroundColor Red
        Wait-TermideskKey
        return
    }

    $step = $steps[$StepKey]
    Export-TermideskHaWizardArtifacts -Settings $s
    $scriptPath = Get-TermideskOutputPath "18-ha-wizard/$($step.Script)"

    Show-TermideskBanner
    Write-Host "  Шаг $StepKey : $($step.Label)" -ForegroundColor Yellow
    Write-Host "  Файл: $scriptPath" -ForegroundColor Gray
    Write-Host ''

    $targetHost = switch ($step.Id) {
        'prepare'    { ($s.cluster.loadBalancers.nodes | Select-Object -First 1).ip }
        'postgres'   { $s.database.host1 }
        'rabbitmq'   { $s.rabbitmq.host }
        'dispatcher' { $s.cluster.referenceNode.ip }
        'dispatchers' { ($s.cluster.dispatchers | Where-Object { -not $_.isReference } | Select-Object -First 1).ip }
        'celery'     { ($s.cluster.celeryManagers | Select-Object -First 1).ip }
        'nginx'      { ($s.cluster.loadBalancers.nodes | Select-Object -First 1).ip }
        default      { $null }
    }

    if ($step.IsGuide -or $step.Id -eq 'verify') {
        if ($step.Id -eq 'verify') {
            if (Test-Path $scriptPath) { & $scriptPath }
        }
        else {
            Get-Content $scriptPath -Raw | Write-Host
        }
        Wait-TermideskKey
        return
    }

    if (-not $targetHost) {
        $targetHost = Invoke-TermideskPromptRequired -Caption 'IP целевого узла для этого шага'
    }

    Write-Host "  Целевой узел: $targetHost" -ForegroundColor Cyan
    if (-not (Confirm-TermideskAction -Message "Выполнить шаг на $targetHost через SSH?")) {
        Wait-TermideskKey
        return
    }

    try {
        $content = Get-Content $scriptPath -Raw -Encoding UTF8
        $code = Invoke-TermideskOnNode -HostAddress $targetHost -ScriptContent $content -ScriptName $step.Script
        if ($code -eq 0) { Write-Host 'Шаг выполнен.' -ForegroundColor Green }
        else { Write-Host "Код выхода: $code" -ForegroundColor Red }
    }
    catch { Write-Host "Ошибка: $_" -ForegroundColor Red }

    $state = Read-TermideskHaWizardState
    if (-not $state) { $state = @{ completedSteps = @() } }
    if ($state.completedSteps -notcontains $StepKey) {
        $state.completedSteps = @($state.completedSteps) + $StepKey
        Save-TermideskHaWizardState -State $state
    }
    Wait-TermideskKey
}

function Invoke-TermideskHaImportFromFileInteractive {
    Show-TermideskBanner
    Write-Host '  Загрузка предзаполненного JSON' -ForegroundColor Yellow
    Write-Host ''
    $template = Get-TermideskHaTemplatePath
    Write-Host "  Шаблон: $template" -ForegroundColor Cyan
    Write-Host '  [1] Скопировать шаблон в config/my-ha-cluster.json и открыть в notepad'
    Write-Host '  [2] Загрузить готовый JSON в termidesk-settings.json'
    Write-Host '  [3] Проверить текущий termidesk-settings.json'
    Write-Host '  [4] Загрузить JSON и сразу сгенерировать скрипты (18-ha-wizard)'
    Write-Host '  [5] Открыть гайд по заполнению шаблона (HTML)'
    Write-Host '  [0] Назад'
    Write-Host ''
    $c = Read-Host '  Выбор'
    switch ($c) {
        '1' {
            $dest = Join-Path (Split-Path (Get-TermideskConfigPath) -Parent) 'my-ha-cluster.json'
            if (-not (Test-Path -LiteralPath $template)) {
                Write-Host "Шаблон не найден: $template" -ForegroundColor Red
            }
            else {
                Copy-Item -LiteralPath $template -Destination $dest -Force
                Write-Host "Создан: $dest" -ForegroundColor Green
                Write-Host 'Замените все __ЗАПОЛНИТЕ__ на реальные значения, сохраните файл,' -ForegroundColor Yellow
                Write-Host 'затем выберите пункт [2] и укажите путь к my-ha-cluster.json.' -ForegroundColor Yellow
                try { Start-Process notepad.exe $dest } catch { Start-Process $dest }
            }
            Wait-TermideskKey
        }
        '2' {
            $path = Invoke-TermideskPromptRequired -Caption 'Путь к JSON-файлу' -Hint "Например: $(Join-Path (Split-Path (Get-TermideskConfigPath) -Parent) 'my-ha-cluster.json')"
            try {
                $s = Import-TermideskSettingsFile -Path $path -Force
                if ($s) {
                    $null = Show-TermideskHaSettingsValidation -Settings $s
                    Save-TermideskHaWizardState -State @{ phase = 'imported'; completedSteps = @(); lastUpdated = (Get-Date -Format 'o'); source = $path }
                }
            }
            catch { Write-Host "Ошибка: $_" -ForegroundColor Red }
            Wait-TermideskKey
        }
        '3' {
            $null = Show-TermideskHaSettingsValidation
            Wait-TermideskKey
        }
        '4' {
            $path = Invoke-TermideskPromptRequired -Caption 'Путь к JSON-файлу'
            try {
                $s = Import-TermideskSettingsFile -Path $path -Force
                if (-not $s) { Wait-TermideskKey; return }
                if (-not (Show-TermideskHaSettingsValidation -Settings $s)) {
                    if (-not (Confirm-TermideskAction -Message 'Есть незаполненные поля. Всё равно сгенерировать скрипты?')) {
                        Wait-TermideskKey
                        return
                    }
                }
                Export-TermideskHaWizardArtifacts -Settings $s
                Save-TermideskHaWizardState -State @{ phase = 'imported'; completedSteps = @(); lastUpdated = (Get-Date -Format 'o'); source = $path }
                Write-Host "Каталог: $(Get-TermideskOutputPath '18-ha-wizard')" -ForegroundColor Cyan
            }
            catch { Write-Host "Ошибка: $_" -ForegroundColor Red }
            Wait-TermideskKey
        }
        '5' {
            $guide = Join-Path (Split-Path -Parent $PSScriptRoot) 'ГАЙД-ШАБЛОН-JSON.html'
            if (Test-Path -LiteralPath $guide) { Start-Process -FilePath $guide }
            else { Write-Host "Не найден: $guide" -ForegroundColor Red }
            Wait-TermideskKey
        }
    }
}

function Invoke-TermideskHaWizardMenuLoop {
    Initialize-TermideskPaths
    do {
        Show-TermideskBanner
        Write-Host '  [18] Пошаговая настройка отказоустойчивого кластера' -ForegroundColor Yellow
        Write-Host '  Без захардкоженных параметров — все значения вводятся вручную или из JSON.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  [1]  Сбор всех параметров (мастер)'
        Write-Host '  [2]  Показать текущую конфигурацию'
        Write-Host '  [3]  Сгенерировать скрипты развёртывания'
        Write-Host '  [4]  Загрузить предзаполненный JSON / шаблон' -ForegroundColor Green
        Write-Host '  [G]  Полное описание настройки кластера (HTML)' -ForegroundColor Green
        Write-Host '  [T]  Гайд по заполнению JSON-шаблона (HTML)' -ForegroundColor Green
        Write-Host '  ─── Пошаговое развёртывание ───' -ForegroundColor DarkGray

        $s = Read-TermideskSettings
        $depType = if ($s) { $s.cluster.deploymentType } else { 'standard' }
        $steps = Get-TermideskHaDeploySteps -DeploymentType $depType
        $wizardState = Read-TermideskHaWizardState
        foreach ($key in $steps.Keys) {
            $mark = ''
            if ($wizardState -and ($wizardState.completedSteps -contains $key)) { $mark = ' [✓]' }
            Write-Host "  [$key]  $($steps[$key].Label)$mark"
        }

        Write-Host '  [R]  Сброс прогресса развёртывания'
        Write-Host '  [0]  Назад'
        Write-Host ''

        $choice = Read-Host '  Выбор'
        switch ($choice.ToUpper()) {
            '1'  { Invoke-TermideskHaWizardCollectParameters }
            '2'  {
                $cfg = Read-TermideskSettings
                if ($cfg) { $cfg | ConvertTo-Json -Depth 10 | Write-Host } else { Write-Host 'Конфигурация не задана.' -ForegroundColor Yellow }
                Wait-TermideskKey
            }
            '3'  {
                Export-TermideskHaWizardArtifacts
                Write-Host "Каталог: $(Get-TermideskOutputPath '18-ha-wizard')" -ForegroundColor Cyan
                Wait-TermideskKey
            }
            '4'  { Invoke-TermideskHaImportFromFileInteractive }
            'G'  {
                $guide = Join-Path (Split-Path -Parent $PSScriptRoot) 'НАСТРОЙКА-КЛАСТЕРА.html'
                if (Test-Path -LiteralPath $guide) {
                    Start-Process -FilePath $guide
                    Write-Host "Открыто: $guide" -ForegroundColor Green
                }
                else {
                    Write-Host "Файл не найден: $guide" -ForegroundColor Red
                }
                Wait-TermideskKey
            }
            'T'  {
                $guide = Join-Path (Split-Path -Parent $PSScriptRoot) 'ГАЙД-ШАБЛОН-JSON.html'
                if (Test-Path -LiteralPath $guide) { Start-Process -FilePath $guide }
                else { Write-Host "Файл не найден: $guide" -ForegroundColor Red }
                Wait-TermideskKey
            }
            'R'  {
                if (Test-Path (Get-TermideskHaWizardStatePath)) { Remove-Item (Get-TermideskHaWizardStatePath) -Force }
                Write-Host 'Прогресс сброшен.' -ForegroundColor Green
                Wait-TermideskKey
            }
            '0'  { return }
            default {
                if ($steps.Contains($choice)) { Invoke-TermideskHaDeployStepInteractive -StepKey $choice }
                else { Write-Host 'Неверный выбор.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
            }
        }
    } while ($true)
}

Export-ModuleMember -Function @(
    'Invoke-TermideskHaWizardMenuLoop',
    'Invoke-TermideskHaWizardCollectParameters',
    'Export-TermideskHaWizardArtifacts',
    'Invoke-TermideskHaDeployStepInteractive',
    'Invoke-TermideskHaImportFromFileInteractive'
)
