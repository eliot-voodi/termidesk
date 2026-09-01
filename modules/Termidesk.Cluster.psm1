# Termidesk 7.0 — отказоустойчивый (распределённый) кластер
# Документация: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/

function New-TermideskClusterConfig {
    [CmdletBinding()]
    param([switch]$Minimal)

    $type = if ($Minimal) { 'minimal' } else { 'standard' }
    Write-Host "Тип развёртывания: $(if ($Minimal) { 'минимальный HA' } else { 'стандартный HA (рекомендуется)' })" -ForegroundColor Cyan

    $domain = Invoke-TermideskPrompt -Caption 'Домен инфраструктуры (например termidesk.local)' -Default 'termidesk.local'

    Show-TermideskStepHeader -Step 1 -Total 6 -Title 'СУБД PostgreSQL'
    Write-Host 'Termidesk подключается к кластеру СУБД (DB_CLUSTER_MODE=cluster).' -ForegroundColor Gray
    Write-Host 'Укажите до 3 узлов PostgreSQL (Patroni/HAProxy и т.п. настраиваются отдельно).' -ForegroundColor Gray
    Write-Host ''

    $dbHost1 = Invoke-TermideskPrompt -Caption 'Адрес узла СУБД 1 (DBHOST)' -Default '192.0.2.10'
    $dbHost2 = Invoke-TermideskPrompt -Caption 'Адрес узла СУБД 2 (DBHOST2, необяз.)' -Default '' -AllowEmpty
    $dbHost3 = Invoke-TermideskPrompt -Caption 'Адрес узла СУБД 3 (DBHOST3, необяз.)' -Default '' -AllowEmpty
    $dbPort  = [int](Invoke-TermideskPrompt -Caption 'Порт PostgreSQL' -Default '5432')
    $dbName  = Invoke-TermideskPrompt -Caption 'Имя БД' -Default 'termidesk'
    $dbUser  = Invoke-TermideskPrompt -Caption 'Пользователь БД' -Default 'termideskdb'
    $dbPass  = Invoke-TermideskPrompt -Caption 'Пароль БД' -Secure

    Show-TermideskStepHeader -Step 2 -Total 6 -Title 'RabbitMQ'
    $rmqHost = Invoke-TermideskPrompt -Caption 'Адрес RabbitMQ' -Default $dbHost1
    $rmqPort = [int](Invoke-TermideskPrompt -Caption 'Порт AMQP' -Default '5672')
    $rmqUser = Invoke-TermideskPrompt -Caption 'Пользователь RabbitMQ' -Default 'admin'
    $rmqPass = Invoke-TermideskPrompt -Caption 'Пароль RabbitMQ' -Secure

    Show-TermideskStepHeader -Step 3 -Total 6 -Title 'Универсальные диспетчеры'
    $dispatcherCount = [int](Invoke-TermideskPrompt -Caption 'Количество диспетчеров (мин. 2)' -Default '2')
    if ($dispatcherCount -lt 2) { $dispatcherCount = 2 }

    $dispatchers = @()
    for ($i = 1; $i -le $dispatcherCount; $i++) {
        Write-Host "  --- Диспетчер $i ---" -ForegroundColor DarkGray
        $name = Invoke-TermideskPrompt -Caption '  Имя узла (NODE_NAME)' -Default "Dispatcher-$('{0:D2}' -f $i)"
        $fqdn = Invoke-TermideskPrompt -Caption '  FQDN' -Default "disp$i.$domain"
        $ip   = Invoke-TermideskPrompt -Caption '  IP-адрес' -Default "192.0.2.$([int]29 + $i)"
        $dispatchers += [PSCustomObject]@{ name = $name; fqdn = $fqdn; ip = $ip; isReference = ($i -eq 1) }
    }

    $celeryManagers = @()
    if ($type -eq 'standard') {
        Show-TermideskStepHeader -Step 4 -Total 6 -Title 'Менеджеры рабочих мест (отдельные узлы)'
        $celeryCount = [int](Invoke-TermideskPrompt -Caption 'Количество узлов CeleryMan (мин. 2)' -Default '2')
        if ($celeryCount -lt 2) { $celeryCount = 2 }

        for ($i = 1; $i -le $celeryCount; $i++) {
            Write-Host "  --- CeleryMan $i ---" -ForegroundColor DarkGray
            $name = Invoke-TermideskPrompt -Caption '  Имя узла' -Default "CeleryMan-$('{0:D2}' -f $i)"
            $fqdn = Invoke-TermideskPrompt -Caption '  FQDN' -Default "tsk$i.$domain"
            $ip   = Invoke-TermideskPrompt -Caption '  IP-адрес' -Default "192.0.2.$([int]39 + $i)"
            $celeryManagers += [PSCustomObject]@{ name = $name; fqdn = $fqdn; ip = $ip }
        }
    }

    Show-TermideskStepHeader -Step 5 -Total 6 -Title 'Termidesk Connect (Шлюзы)'
    $gwCount = [int](Invoke-TermideskPrompt -Caption 'Количество шлюзов (мин. 2)' -Default '2')
    if ($gwCount -lt 2) { $gwCount = 2 }

    $gateways = @()
    for ($i = 1; $i -le $gwCount; $i++) {
        Write-Host "  --- Шлюз $i ---" -ForegroundColor DarkGray
        $name = Invoke-TermideskPrompt -Caption '  Имя' -Default "Gateway-$('{0:D2}' -f $i)"
        $fqdn = Invoke-TermideskPrompt -Caption '  FQDN' -Default "tdc-gw$i.$domain"
        $ip   = Invoke-TermideskPrompt -Caption '  IP-адрес' -Default "192.0.2.$([int]49 + $i)"
        $port = [int](Invoke-TermideskPrompt -Caption '  Порт websockify' -Default '5099')
        $gateways += [PSCustomObject]@{ name = $name; fqdn = $fqdn; ip = $ip; port = $port }
    }

    Show-TermideskStepHeader -Step 6 -Total 6 -Title 'Балансировщик и SSH'
    $lbFqdn = Invoke-TermideskPrompt -Caption 'FQDN портала (VIP балансировщика)' -Default "portal.$domain"
    $sshUser = Invoke-TermideskPrompt -Caption 'SSH-пользователь для удалённого выполнения' -Default 'admin'
    $sshPort = [int](Invoke-TermideskPrompt -Caption 'SSH-порт' -Default '22')
    $sshKey  = Invoke-TermideskPrompt -Caption 'Путь к SSH-ключу (необяз.)' -Default '' -AllowEmpty

    $ref = $dispatchers | Where-Object { $_.isReference } | Select-Object -First 1

    $config = [PSCustomObject]@{
        version        = '7.0'
        deploymentType = $type
        domain         = $domain
        secretsStorage = 'config'
        database       = [PSCustomObject]@{
            clusterMode = 'cluster'
            host1       = $dbHost1
            host2       = $dbHost2
            host3       = $dbHost3
            port        = $dbPort
            name        = $dbName
            user        = $dbUser
            password    = $dbPass
        }
        rabbitmq = [PSCustomObject]@{
            host     = $rmqHost
            port     = $rmqPort
            user     = $rmqUser
            password = $rmqPass
            vhost    = '/'
        }
        dispatchers    = $dispatchers
        celeryManagers = $celeryManagers
        gateways       = $gateways
        loadBalancers  = [PSCustomObject]@{
            fqdn             = $lbFqdn
            useSelfSignedCert = $true
            nginxNodes       = @()
        }
        ssh = [PSCustomObject]@{
            user    = $sshUser
            port    = $sshPort
            keyPath = $sshKey
        }
        referenceNode = [PSCustomObject]@{
            name = $ref.name
            ip   = $ref.ip
            fqdn = $ref.fqdn
        }
    }

    Save-TermideskConfig -Config $config
    return $config
}

function Edit-TermideskClusterConfig {
    $config = Read-TermideskConfig
    if (-not $config) {
        Write-Host 'Конфигурация не найдена. Запустите мастер настройки.' -ForegroundColor Yellow
        return
    }
    Write-Host 'Текущая конфигурация кластера:' -ForegroundColor Cyan
    $config | ConvertTo-Json -Depth 6 | Write-Host
    Write-Host ''
    Write-Host 'Для изменения параметров запустите мастер [1] или отредактируйте файл:' -ForegroundColor Gray
    Write-Host (Get-TermideskConfigPath) -ForegroundColor White
    Wait-TermideskKey
}

function Show-TermideskDeploymentPlan {
    param($Config)

    if (-not $Config) { $Config = Read-TermideskConfig }
    if (-not $Config) {
        Write-Host 'Конфигурация кластера не задана.' -ForegroundColor Red
        return
    }

    Show-TermideskBanner
    Write-Host '  План развёртывания отказоустойчивого кластера' -ForegroundColor Yellow
    Write-Host "  Тип: $($Config.deploymentType) | Домен: $($Config.domain)" -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Последовательность (Termidesk 7.0, стандартная распределённая установка):' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1. PostgreSQL + RabbitMQ на инфраструктурном узле (чистая БД!)'
    Write-Host '  2. Первый эталонный Универсальный диспетчер (ADMIN + USER)'
    if ($Config.deploymentType -eq 'minimal') {
        Write-Host '     + Менеджер рабочих мест на тех же узлах (CELERYMAN)'
    }
    Write-Host '  3. Копирование /etc/opt/termidesk-vdi на остальные диспетчеры'
    Write-Host '  4. Установка дополнительных диспетчеров (те же параметры БД/RabbitMQ)'
    Write-Host '  5. Termidesk Connect — настройка шлюзов'
    if ($Config.deploymentType -eq 'standard') {
        Write-Host '  6. Установка Менеджеров рабочих мест (NODE_ROLES=CELERYMAN)'
    }
    Write-Host '  7. Балансировщики нагрузки (nginx / Termidesk Connect LB)'
    Write-Host '  8. Проверка через раздел «Инфраструктура» в портале администратора'
    Write-Host ''
    Write-Host '  Компоненты:' -ForegroundColor Cyan

    Write-Host '    СУБД:' -ForegroundColor White
    Write-Host "      $($Config.database.host1)" -NoNewline
    if ($Config.database.host2) { Write-Host ", $($Config.database.host2)" -NoNewline }
    if ($Config.database.host3) { Write-Host ", $($Config.database.host3)" -NoNewline }
    Write-Host " :$($Config.database.port)"

    Write-Host "    RabbitMQ: $($Config.rabbitmq.host):$($Config.rabbitmq.port)"
    Write-Host '    Диспетчеры:'
    foreach ($d in $Config.dispatchers) {
        $mark = if ($d.isReference) { ' [эталон]' } else { '' }
        Write-Host "      $($d.name) — $($d.fqdn) ($($d.ip))$mark"
    }
    if ($Config.celeryManagers -and $Config.celeryManagers.Count -gt 0) {
        Write-Host '    Менеджеры рабочих мест:'
        foreach ($c in $Config.celeryManagers) {
            Write-Host "      $($c.name) — $($c.fqdn) ($($c.ip))"
        }
    }
    Write-Host '    Шлюзы (Termidesk Connect):'
    foreach ($g in $Config.gateways) {
        Write-Host "      $($g.name) — $($g.fqdn) ($($g.ip):$($g.port))"
    }
    Write-Host "    Портал (VIP): $($Config.loadBalancers.fqdn)"
    Write-Host ''
    Write-Host "  Документация: $(Get-TermideskDocLink -Section cluster)" -ForegroundColor Gray
    Wait-TermideskKey
}

function New-TermideskPostgresScript {
    param($Config)

    $db = $Config.database
    @"
#!/bin/bash
# Termidesk 7.0 — установка и настройка PostgreSQL
# Узел: инфраструктурный сервер СУБД
# Документация: $(Get-TermideskDocLink -Section prepare)

set -euo pipefail

echo "=== Установка PostgreSQL ==="
sudo apt update
sudo apt install -y postgresql

echo "=== Создание БД и пользователя ==="
sudo su - postgres -c "psql -c \"CREATE DATABASE $($db.name) LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;\"" 2>/dev/null || echo "БД уже существует"
sudo su - postgres -c "psql -c \"CREATE USER $($db.user) WITH PASSWORD '$($db.password)';\"" 2>/dev/null || echo "Пользователь уже существует"
sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $($db.name) TO $($db.user);\""
sudo su - postgres -c "psql -c \"ALTER DATABASE $($db.name) OWNER TO $($db.user);\"" 2>/dev/null || true

echo "=== Настройка pg_hba.conf (разрешить подключения Termidesk) ==="
echo "Проверьте listen_addresses и pg_hba.conf для доступа с узлов Termidesk."

echo "=== Готово ==="
echo "DBHOST=$($db.host1) DBNAME=$($db.name) DBUSER=$($db.user)"
"@ | Out-String
}

function New-TermideskRabbitMqScript {
    param($Config)

    $rmq = $Config.rabbitmq
    $envConf = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'rabbitmq-env.conf.template') -Variables @{
        RABBITMQ_PORT = $rmq.port
    }
    $mainConf = Read-TermideskTemplate 'rabbitmq.conf.template'

    @"
#!/bin/bash
# Termidesk 7.0 — установка и настройка RabbitMQ
set -euo pipefail

echo "=== Установка RabbitMQ ==="
sudo apt update
sudo apt install -y rabbitmq-server

sudo mkdir -p /etc/rabbitmq

cat <<'RABBITMQ_CONF_EOF' | sudo tee /etc/rabbitmq/rabbitmq.conf
$mainConf
RABBITMQ_CONF_EOF

cat <<'RABBITMQ_ENV_EOF' | sudo tee /etc/rabbitmq/rabbitmq-env.conf
$envConf
RABBITMQ_ENV_EOF

sudo touch /etc/rabbitmq/definitions.json
sudo chown rabbitmq:rabbitmq /etc/rabbitmq/definitions.json /etc/rabbitmq/rabbitmq.conf /etc/rabbitmq/rabbitmq-env.conf

echo "=== Включение management plugin ==="
sudo rabbitmq-plugins enable rabbitmq_management

echo "=== Настройка tcp keepalive ==="
if ! grep -q tcp_keepalive_time /etc/sysctl.conf 2>/dev/null; then
  cat <<'SYSCTL_EOF' | sudo tee -a /etc/sysctl.conf
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
SYSCTL_EOF
  sudo sysctl -p
fi

echo "=== Перезапуск RabbitMQ ==="
sudo systemctl restart rabbitmq-server
sudo systemctl enable rabbitmq-server

echo ""
echo "ВАЖНО: Задайте пароль через rabbitmq_password2hash.sh из репозитория Termidesk"
echo "       и добавьте пользователя '$($rmq.user)' в /etc/rabbitmq/definitions.json"
echo "URL для Termidesk: amqp://$($rmq.user):***@$($rmq.host):$($rmq.port)$($rmq.vhost)"
"@ | Out-String
}

function New-TermideskDispatcherGuide {
    param(
        $Config,
        [switch]$Reference,
        [switch]$Additional
    )

    $db = $Config.database
    $rmq = $Config.rabbitmq
    $ref = $Config.referenceNode

    if ($Reference) {
        $roles = 'ADMIN,USER'
        if ($Config.deploymentType -eq 'minimal') { $roles = 'ADMIN,USER,CELERYMAN' }
        $title = 'Первый (эталонный) Универсальный диспетчер'
        $extra = @"

После установки:
  sudo scp -r /etc/opt/termidesk-vdi $($Config.ssh.user)@<целевой_хост>:/home/$($Config.ssh.user)/

Эталонный узел: $($ref.fqdn) ($($ref.ip))
"@
    }
    else {
        $roles = 'ADMIN,USER'
        $title = 'Дополнительный Универсальный диспетчер'
        $extra = @"

ПЕРЕД установкой скопируйте каталог с эталонного узла:
  scp -r $($Config.ssh.user)@$($ref.ip):/etc/opt/termidesk-vdi /tmp/
  sudo mv /tmp/termidesk-vdi /etc/opt/

Затем установите пакет с теми же параметрами БД и RabbitMQ.
"@
    }

    @"
# Termidesk 7.0 — $title
# Документация: $(Get-TermideskDocLink -Section cluster)

## Параметры установки (termidesk-vdi installer / termidesk-config)

TERMIDESK_FARM_MODE = dispatcher
NODE_ROLES = $roles
NODE_NAME = <уникальное_имя_узла>

## СУБД
DB_CLUSTER_MODE = $($db.clusterMode)
DBHOST  = $($db.host1)
DBHOST2 = $($db.host2)
DBHOST3 = $($db.host3)
DBPORT  = $($db.port)
DBNAME  = $($db.name)
DBUSER  = $($db.user)

## RabbitMQ
RABBITMQ_URL = amqp://$($rmq.user):<password>@$($rmq.host):$($rmq.port)$($rmq.vhost)

## Команды
sudo apt install -y termidesk-vdi
cd /opt/termidesk/sbin && sudo ./termidesk-config
# Выберите «Перезапуск служб» после изменений

$extra
"@ | Out-String
}

function New-TermideskCeleryScript {
    param($Config)

    $node = $Config.celeryManagers | Select-Object -First 1
    $local = Read-TermideskTemplate 'termidesk-vdi.local.template'

    @"
#!/bin/bash
# Termidesk 7.0 — установка Менеджера рабочих мест (CELERYMAN)
# Active-Active: оба узла обрабатывают задачи, termidesk-celery-beat — active-passive через БД
set -euo pipefail

echo "=== Подготовка каталога конфигурации ==="
# Скопируйте /etc/opt/termidesk-vdi с эталонного диспетчера перед выполнением

sudo touch /etc/default/termidesk-vdi.local
cat <<'LOCAL_EOF' | sudo tee /etc/default/termidesk-vdi.local
$local
LOCAL_EOF

echo "=== Установка NODE_ROLES=CELERYMAN ==="
sudo sed -i "s/^NODE_ROLES=.*/NODE_ROLES='CELERYMAN'/" /etc/opt/termidesk-vdi/termidesk.conf

echo "=== Установка пакета ==="
sudo apt -y install termidesk-vdi

echo "=== Проверка служб ==="
sudo systemctl status termidesk-celery-beat --no-pager
sudo systemctl status termidesk-celery-worker --no-pager

echo "=== Рекомендуемые параметры termidesk.conf для HA ==="
echo "CELERY_BEAT_PRIMARY_CHECK_INTERVAL=3"
echo "CELERY_BEAT_PRIMARY_LOCK_TIMEOUT=45"
echo "CELERY_BEAT_HEALTH_CHECK_IP=<IP_этого_узла>"
echo "CELERY_WORKER_HEALTH_CHECK_IP=<IP_этого_узла>"
"@ | Out-String
}

function New-TermideskGatewayGuide {
    param($Config)

    $lines = ($Config.gateways | ForEach-Object { "  - $($_.fqdn) ($($_.ip):$($_.port))" }) -join "`n"

    @"
# Termidesk 7.0 — настройка Termidesk Connect (Шлюзы)
# С Termidesk 6.1+ шлюз реализуется через Termidesk Connect Basic
#
# Документация:
#   https://termidesk.ru/docs/ru-connect-doc/v1.3/tech-materials/how-to/config-gateway.html
#   https://termidesk.ru/docs/ru-connect-doc/v1.3/tech-materials/how-to/config-gateway-2.html

Шлюзы в кластере:
$lines

Для каждого шлюза:
  1. Установите Termidesk Connect
  2. Настройте регистрацию в RabbitMQ (coordinatorUrl, coordinatorUser, coordinatorPass)
  3. Настройте websockify на порту 5099 (по умолчанию)
  4. Проверьте healthcheck endpoint

Балансировка websockify — через upstream daas-upstream-ws в nginx (см. nginx-site.conf)
"@ | Out-String
}

function Get-TermideskNginxTlsFromSettings {
    param($Settings)
    if (-not $Settings) { $Settings = Read-TermideskSettings }

    $tls = $Settings.cluster.tls
    $ngx = $Settings.cluster.nginx

    if (-not $tls -and $Settings.nginx) {
        $tls = [PSCustomObject]@{
            mode = if ($Settings.cluster.loadBalancers.useSelfSignedCert) { 'selfsigned' } else { 'provided' }
            certPath = $Settings.nginx.certPath
            keyPath = $Settings.nginx.keyPath
            dhparamPath = '/etc/nginx/dhparam.pem'
            certDays = 365; certKeySize = 2048; certSubject = $Settings.cluster.loadBalancers.fqdn
            sslProtocols = 'TLSv1.3 TLSv1.2'
            sslCiphers = 'ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384'
            sslEcdhCurve = 'secp384r1'; sslSessionTimeout = '10m'; sslSessionCacheSize = '10m'
            sslStapling = 'on'; sslStaplingVerify = 'on'
            dnsResolverPrimary = $Settings.environment.dnsResolverPrimary
            dnsResolverSecondary = $Settings.environment.dnsResolverSecondary
            dnsResolverValid = 300; dnsResolverTimeout = 5
        }
    }
    if (-not $ngx) {
        $ngx = [PSCustomObject]@{
            listenHttp = '0.0.0.0:80'; listenHttps = '0.0.0.0:443 ssl'
            dispatcherPort = 443; proxyTimeout = 1000
            snippetsDir = '/etc/nginx/snippets'
            sitesAvailableDir = '/etc/nginx/sites-available'
            sitesEnabledDir = '/etc/nginx/sites-enabled'
            sslSnippetCert = 'snippets/ssl-cert.conf'
            sslSnippetParams = 'snippets/ssl-params.conf'
        }
    }
    return @{ Tls = $tls; Nginx = $ngx }
}

function New-TermideskNginxConfig {
    param($Config)

    $settings = Read-TermideskSettings
    $resolved = Get-TermideskNginxTlsFromSettings -Settings $settings
    $tls = $resolved.Tls
    $ngx = $resolved.Nginx
    $dispPort = if ($ngx.dispatcherPort) { $ngx.dispatcherPort } else { 443 }

    $gwLines = ($Config.gateways | ForEach-Object {
        "     server $($_.ip):$($_.port);"
    }) -join "`n"

    $dispLines = ($Config.dispatchers | ForEach-Object {
        "     server $($_.ip):$dispPort;"
    }) -join "`n"

    $siteConf = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'nginx-site.conf.template') -Variables @{
        GATEWAY_UPSTREAMS    = $gwLines
        DISPATCHER_UPSTREAMS = $dispLines
        LISTEN_HTTP          = $ngx.listenHttp
        LISTEN_HTTPS         = $ngx.listenHttps
        SSL_SNIPPET_CERT     = $ngx.sslSnippetCert
        SSL_SNIPPET_PARAMS   = $ngx.sslSnippetParams
        PROXY_TIMEOUT        = $ngx.proxyTimeout
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
echo "=== Генерация самоподписанного сертификата ==="
sudo openssl req -new -x509 -nodes -days $($tls.certDays) -newkey rsa:$($tls.certKeySize) \
  -keyout $($tls.keyPath) -out $($tls.certPath) -subj "/CN=$($tls.certSubject)"
sudo openssl dhparam -out $($tls.dhparamPath) 4096
"@
    } else {
        "echo '=== Используются предоставленные сертификаты: $($tls.certPath) ==='"
    }

    @"
#!/bin/bash
# Termidesk 7.0 — настройка nginx балансировщика
# Документация: $(Get-TermideskDocLink -Section distributed)
set -euo pipefail

FQDN="$($Config.loadBalancers.fqdn)"

echo "=== Установка nginx ==="
sudo apt install -y nginx openssl

$certGen

sudo mkdir -p $($ngx.snippetsDir)
cat <<'CERT_EOF' | sudo tee $($ngx.snippetsDir)/ssl-cert.conf
$sslCertSnippet
CERT_EOF

cat <<'SSL_EOF' | sudo tee $($ngx.snippetsDir)/ssl-params.conf
$sslParamsSnippet
SSL_EOF

SITE="$($ngx.sitesAvailableDir)/`${FQDN}.conf"
cat <<'SITE_EOF' | sudo tee "`$SITE"
$siteConf
SITE_EOF

sudo ln -sf "`$SITE" $($ngx.sitesEnabledDir)/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "=== Балансировщик настроен для `$FQDN ==="
"@ | Out-String
}

function New-TermideskHealthCheckScript {
    param($Config)

    $pingLines = @()
    foreach ($d in $Config.dispatchers) {
        $pingLines += "Test-Node '$($d.ip)' '$($d.name) (dispatcher)'"
    }
    foreach ($c in $Config.celeryManagers) {
        $pingLines += "Test-Node '$($c.ip)' '$($c.name) (celery)'"
    }
    foreach ($g in $Config.gateways) {
        $pingLines += "Test-Node '$($g.ip)' '$($g.name) (gateway)'"
    }
    $pingLines += "Test-Node '$($Config.database.host1)' 'PostgreSQL'"
    $pingLines += "Test-Node '$($Config.rabbitmq.host)' 'RabbitMQ'"
    $pingBlock = ($pingLines | Select-Object -Unique) -join "`n"

    @"
# Termidesk 7.0 — проверка готовности кластера
param()

function Test-Node {
    param([string]`$Ip, [string]`$Label)
    Write-Host -NoNewline "  `$Label (`$Ip): "
    if (Test-Connection -ComputerName `$Ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Host 'OK' -ForegroundColor Green
    } else {
        Write-Host 'FAIL' -ForegroundColor Red
    }
}

Write-Host '=== Проверка сетевой доступности узлов ===' -ForegroundColor Cyan
$pingBlock

Write-Host ''
Write-Host '=== Сервисы ===' -ForegroundColor Cyan
Write-Host "  PostgreSQL : $($Config.database.host1):$($Config.database.port)"
Write-Host "  RabbitMQ   : $($Config.rabbitmq.host):$($Config.rabbitmq.port)"
Write-Host "  Портал VIP : https://$($Config.loadBalancers.fqdn)"
Write-Host ''
Write-Host 'На Linux-узлах выполните:' -ForegroundColor Gray
Write-Host '  systemctl status termidesk-vdi termidesk-celery-beat termidesk-celery-worker'
"@
}

function Export-TermideskClusterArtifacts {
    param($Config)

    if (-not $Config) { $Config = Read-TermideskConfig }
    if (-not $Config) {
        Write-Host 'Сначала создайте конфигурацию кластера (мастер [1]).' -ForegroundColor Red
        return
    }

    $base = "cluster-$($Config.deploymentType)"
    $files = @{}

    $files["$base/01-postgresql-setup.sh"]       = New-TermideskPostgresScript -Config $Config
    $files["$base/02-rabbitmq-setup.sh"]         = New-TermideskRabbitMqScript -Config $Config
    $files["$base/03-dispatcher-reference.md"]   = New-TermideskDispatcherGuide -Config $Config -Reference
    $files["$base/04-dispatcher-additional.md"]  = New-TermideskDispatcherGuide -Config $Config -Additional
    $files["$base/05-celery-setup.sh"]           = New-TermideskCeleryScript -Config $Config
    $files["$base/06-gateway-setup.md"]          = New-TermideskGatewayGuide -Config $Config
    $files["$base/07-nginx-lb-setup.sh"]         = New-TermideskNginxConfig -Config $Config
    $files["$base/08-healthcheck.ps1"]           = New-TermideskHealthCheckScript -Config $Config
    $files["$base/termidesk.conf.snippet"]       = New-TermideskConfSnippet -Config $Config
    $files["$base/README-deploy-order.txt"]      = New-TermideskDeployReadme -Config $Config

    $written = @()
    foreach ($entry in $files.GetEnumerator()) {
        $path = Write-TermideskFile -RelativePath $entry.Key -Content $entry.Value
        $written += $path
    }

    Write-Host ''
    Write-Host 'Сгенерировано файлов:' ($written.Count) -ForegroundColor Green
    foreach ($p in $written) {
        Write-Host "  $p" -ForegroundColor Gray
    }
    Write-Host ''
    Write-Host "Каталог: $(Get-TermideskOutputPath)" -ForegroundColor Cyan
}

function New-TermideskConfSnippet {
    param($Config)

    $db = $Config.database
    $rmq = $Config.rabbitmq

    @"
# Фрагмент /etc/opt/termidesk-vdi/termidesk.conf для кластера Termidesk 7.0
# Применять через termidesk-config или вручную, затем перезапустить службы

TERMIDESK_FARM_MODE='dispatcher'
NODE_ROLES='ADMIN,USER'
NODE_NAME='<уникальное_имя>'

DB_CLUSTER_MODE='$($db.clusterMode)'
DBHOST='$($db.host1)'
DBHOST2='$($db.host2)'
DBHOST3='$($db.host3)'
DBPORT='$($db.port)'
DBNAME='$($db.name)'
DBUSER='$($db.user)'
# DBPASS — через scramble или OpenBao

RABBITMQ_URL='amqp://$($rmq.user):<password>@$($rmq.host):$($rmq.port)$($rmq.vhost)'

# HA — Менеджер рабочих мест
CELERY_BEAT_PRIMARY_CHECK_INTERVAL='3'
CELERY_BEAT_PRIMARY_LOCK_TIMEOUT='45'
CELERY_BEAT_HEALTH_CHECK_IP='<ip_узла>'
CELERY_WORKER_HEALTH_CHECK_IP='<ip_узла>'

# TermideskMQ (если используется вместо RabbitMQ)
# TMQ_CLIENT_ID='<pool_id>'
# TMQ_TIMEOUT_AWAIT_SENDING_MESSAGE='5000'
# TMQ_PUT_RETRY_COUNT='3'
"@
}

function New-TermideskDeployReadme {
    param($Config)

    @"
Termidesk VDI 7.0 — порядок развёртывания отказоустойчивого кластера
Тип: $($Config.deploymentType)
Дата генерации: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

1. 01-postgresql-setup.sh     — на узле СУБД ($($Config.database.host1))
2. 02-rabbitmq-setup.sh       — на узле RabbitMQ ($($Config.rabbitmq.host))
3. 03-dispatcher-reference.md — первый диспетчер ($($Config.referenceNode.fqdn))
4. 04-dispatcher-additional.md — остальные диспетчеры
5. 05-celery-setup.sh         — менеджеры рабочих мест (если standard)
6. 06-gateway-setup.md        — Termidesk Connect шлюзы
7. 07-nginx-lb-setup.sh       — балансировщик ($($Config.loadBalancers.fqdn))
8. 08-healthcheck.ps1         — проверка с Windows

Важно:
- Используйте чистую БД без записей Termidesk
- Скопируйте /etc/opt/termidesk-vdi с эталонного узла на все остальные
- OpenBao для HA должен быть отказоустойчивым
- Синхронизация времени (NTP) на всех узлах обязательна

Документация: $(Get-TermideskDocLink -Section cluster)
"@
}

function Invoke-TermideskClusterStep {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('postgres', 'dispatcher-ref', 'dispatcher-add', 'celery', 'gateway', 'nginx')]
        [string]$Step
    )

    $config = Read-TermideskConfig
    if (-not $config) {
        Write-Host 'Конфигурация не найдена.' -ForegroundColor Red
        return
    }

    Export-TermideskClusterArtifacts -Config $config

    $scriptMap = @{
        postgres       = '01-postgresql-setup.sh'
        'dispatcher-ref'  = $null
        'dispatcher-add'  = $null
        celery         = '05-celery-setup.sh'
        gateway        = $null
        nginx          = '07-nginx-lb-setup.sh'
    }

    if ($Step -match 'dispatcher|gateway') {
        Write-Host 'Для этого шага используйте сгенерированные инструкции (.md) в каталоге output.' -ForegroundColor Yellow
        Show-TermideskDeploymentPlan -Config $config
        return
    }

    $rel = $scriptMap[$Step]
    if (-not $rel) { return }

    $scriptPath = Get-TermideskOutputPath -SubPath "cluster-$($config.deploymentType)/$rel"

    $targetHost = switch ($Step) {
        'postgres' { $config.database.host1 }
        'celery'   { ($config.celeryManagers | Select-Object -First 1).ip }
        'nginx'    { $config.loadBalancers.fqdn }
        default    { $null }
    }

    if (-not $targetHost) {
        Write-Host 'Не удалось определить целевой хост.' -ForegroundColor Red
        return
    }

    Write-Host "Целевой хост: $targetHost" -ForegroundColor Cyan
    Write-Host "Скрипт: $scriptPath" -ForegroundColor Gray

    if (-not (Confirm-TermideskAction -Message "Выполнить скрипт на $targetHost через SSH?")) {
        Write-Host 'Отменено. Скрипт доступен для ручного запуска.' -ForegroundColor Yellow
        return
    }

    try {
        $code = Invoke-TermideskRemoteScript -HostAddress $targetHost -ScriptPath $scriptPath `
            -User $config.ssh.user -Port $config.ssh.port -KeyPath $config.ssh.keyPath
        if ($code -eq 0) {
            Write-Host 'Шаг выполнен успешно.' -ForegroundColor Green
        }
        else {
            Write-Host "SSH завершился с кодом $code" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Ошибка: $_" -ForegroundColor Red
        Write-Host 'Выполните скрипт вручную на целевом узле.' -ForegroundColor Yellow
    }
}

function Invoke-TermideskClusterWizard {
    Show-TermideskBanner
    Write-Host '  Мастер настройки отказоустойчивого кластера Termidesk 7.0' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Стандартная распределённая установка (рекомендуется для HA)'
    Write-Host '  [2] Минимальная распределённая установка'
    Write-Host '  [0] Отмена'
    Write-Host ''

    $choice = Read-Host '  Выбор'
    switch ($choice) {
        '1' {
            $config = New-TermideskClusterConfig
            Export-TermideskClusterArtifacts -Config $config
            Show-TermideskDeploymentPlan -Config $config
        }
        '2' {
            $config = New-TermideskClusterConfig -Minimal
            Export-TermideskClusterArtifacts -Config $config
            Show-TermideskDeploymentPlan -Config $config
        }
        default { return }
    }
}

function Invoke-TermideskClusterHealthCheck {
    $config = Read-TermideskConfig
    if (-not $config) {
        Write-Host 'Конфигурация не найдена.' -ForegroundColor Red
        Wait-TermideskKey
        return
    }

    Export-TermideskClusterArtifacts -Config $config
    $script = Get-TermideskOutputPath -SubPath "cluster-$($config.deploymentType)/08-healthcheck.ps1"

    Write-Host '=== Проверка кластера ===' -ForegroundColor Cyan
    Write-Host ''

    $allNodes = @()
    $allNodes += $config.database.host1, $config.database.host2, $config.database.host3
    $allNodes += $config.rabbitmq.host
    $allNodes += $config.dispatchers.ip
    $allNodes += $config.celeryManagers.ip
    $allNodes += $config.gateways.ip
    $allNodes = $allNodes | Where-Object { $_ } | Select-Object -Unique

    foreach ($node in $allNodes) {
        Write-Host -NoNewline "  $node : "
        if (Test-Connection -ComputerName $node -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            Write-Host 'OK' -ForegroundColor Green
        }
        else {
            Write-Host 'FAIL' -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-Host "  PostgreSQL : $($config.database.host1):$($config.database.port)" -ForegroundColor Gray
    Write-Host "  RabbitMQ   : $($config.rabbitmq.host):$($config.rabbitmq.port)" -ForegroundColor Gray
    Write-Host "  Портал VIP : https://$($config.loadBalancers.fqdn)" -ForegroundColor Gray
    Write-Host ''
    Write-Host "Полный скрипт: $script" -ForegroundColor DarkGray
    Wait-TermideskKey
}

function Invoke-TermideskClusterMenuLoop {
    do {
        Show-TermideskClusterMenu
        $choice = Read-Host '  Выбор'

        switch ($choice) {
            '1'  { Invoke-TermideskClusterWizard }
            '2'  { Edit-TermideskClusterConfig }
            '3'  { Export-TermideskClusterArtifacts; Wait-TermideskKey }
            '4'  { Invoke-TermideskClusterStep -Step postgres; Wait-TermideskKey }
            '5'  { Invoke-TermideskClusterStep -Step 'dispatcher-ref'; Wait-TermideskKey }
            '6'  { Invoke-TermideskClusterStep -Step 'dispatcher-add'; Wait-TermideskKey }
            '7'  { Invoke-TermideskClusterStep -Step celery; Wait-TermideskKey }
            '8'  { Invoke-TermideskClusterStep -Step gateway; Wait-TermideskKey }
            '9'  { Invoke-TermideskClusterStep -Step nginx; Wait-TermideskKey }
            '10' { Invoke-TermideskClusterHealthCheck }
            '11' { Show-TermideskDeploymentPlan }
            '0'  { return }
            default {
                Write-Host '  Неверный выбор.' -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

Export-ModuleMember -Function @(
    'New-TermideskClusterConfig',
    'Edit-TermideskClusterConfig',
    'Show-TermideskDeploymentPlan',
    'Export-TermideskClusterArtifacts',
    'Invoke-TermideskClusterStep',
    'Invoke-TermideskClusterWizard',
    'Invoke-TermideskClusterHealthCheck',
    'Invoke-TermideskClusterMenuLoop'
)
