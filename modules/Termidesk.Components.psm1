# Termidesk 7.0 — компоненты (пункты 6–11)

function Get-TermideskSettingsOrNew {
    $s = Read-TermideskSettings
    if ($s) { return $s }
    $example = Join-Path $Script:TermideskConfig 'termidesk-settings.example.json'
    Copy-Item $example (Get-TermideskConfigPath) -Force
    return Read-TermideskSettings
}

function Export-TermideskDispatcherScripts {
    $s = Get-TermideskSettingsOrNew
    $db = $s.database; $rmq = $s.rabbitmq; $d = $s.dispatcher
    $ref = $s.cluster.referenceNode

    $install = @"
#!/bin/bash
# Установка Универсального диспетчера — Termidesk 7.0
set -euo pipefail
sudo apt install -y termidesk-vdi
cd /opt/termidesk/sbin && sudo ./termidesk-config
# Роли: $($d.nodeRoles) | NODE_NAME: $($d.nodeName)
sudo systemctl enable termidesk-vdi && sudo systemctl start termidesk-vdi
"@

    $conf = @"
TERMIDESK_FARM_MODE='$($d.farmMode)'
NODE_ROLES='$($d.nodeRoles)'
NODE_NAME='$($d.nodeName)'
DB_CLUSTER_MODE='$($db.clusterMode)'
DBHOST='$($db.host1)' DBHOST2='$($db.host2)' DBHOST3='$($db.host3)'
DBPORT='$($db.port)' DBNAME='$($db.name)' DBUSER='$($db.user)'
RABBITMQ_URL='amqp://$($rmq.user):<pass>@$($rmq.host):$($rmq.port)$($rmq.vhost)'
"@

    $copyGuide = @"
# Копирование конфигурации на доп. диспетчеры
sudo scp -r /etc/opt/termidesk-vdi $($s.ssh.user)@<target>:/home/$($s.ssh.user)/
ssh $($s.ssh.user)@<target> 'sudo mv /home/$($s.ssh.user)/termidesk-vdi /etc/opt/'
# Затем apt install termidesk-vdi с теми же параметрами БД/RabbitMQ
Эталон: $($ref.fqdn) ($($ref.ip))
"@

    Export-TermideskArtifacts -Section '06-dispatcher' -Files @{
        '01-install-dispatcher.sh' = $install
        'termidesk.conf.snippet'   = $conf
        'copy-to-additional.md'    = $copyGuide
    }
}

function Export-TermideskCeleryScripts {
    $s = Get-TermideskSettingsOrNew
    $c = $s.celery
    $local = Read-TermideskTemplate 'termidesk-vdi.local.template'

    $install = @"
#!/bin/bash
set -euo pipefail
sudo mv /home/$($s.ssh.user)/termidesk-vdi /etc/opt/ 2>/dev/null || true
sudo touch /etc/default/termidesk-vdi.local
cat <<'EOF' | sudo tee /etc/default/termidesk-vdi.local
$local
EOF
sudo sed -i "s/^NODE_ROLES=.*/NODE_ROLES='$($c.nodeRoles)'/" /etc/opt/termidesk-vdi/termidesk.conf
sudo apt -y install termidesk-vdi
sudo systemctl status termidesk-celery-beat termidesk-celery-worker --no-pager
"@

    $conf = @"
NODE_ROLES='$($c.nodeRoles)'
CELERY_BEAT_PRIMARY_CHECK_INTERVAL='$($c.primaryCheckInterval)'
CELERY_BEAT_PRIMARY_LOCK_TIMEOUT='$($c.primaryLockTimeout)'
CELERY_BEAT_HEALTH_CHECK_PORT='$($c.beatHealthCheckPort)'
CELERY_WORKER_HEALTH_CHECK_PORT='$($c.workerHealthCheckPort)'
CELERY_BEAT_HEALTH_CHECK_IP='$($c.beatHealthCheckIp)'
CELERY_WORKER_HEALTH_CHECK_IP='$($c.workerHealthCheckIp)'
"@

    Export-TermideskArtifacts -Section '07-celery' -Files @{
        '01-install-celery.sh'   = $install
        'termidesk.conf.snippet' = $conf
    }
}

function Export-TermideskGatewayScripts {
    $s = Get-TermideskSettingsOrNew
    $g = $s.gateway

    $yaml = @"
# gateway.yaml — Termidesk Connect / Шлюз
coordinatorUrl: $($g.coordinatorUrl)
coordinatorUser: $($g.coordinatorUser)
coordinatorPass: $($g.coordinatorPass)
coordinatorTimeout: $($g.coordinatorTimeout)
coordinatorRefreshTime: $($g.coordinatorRefreshTime)
healthCheckURL: $($g.healthCheckPath)
listenPort: $($g.listenPort)
"@

    $guide = @"
# Termidesk Connect — настройка шлюзов Termidesk VDI 7.0
# https://termidesk.ru/docs/ru-connect-doc/v1.3/tech-materials/how-to/config-gateway.html

1. Установите Termidesk Connect Basic на каждый узел шлюза
2. Скопируйте gateway.yaml в /etc/opt/termidesk-gateway/
3. Зарегистрируйте шлюз в RabbitMQ (coordinatorUrl)
4. Проверьте healthcheck: curl -k https://<gw>:443$($g.healthCheckPath)

Шлюзы кластера:
$($s.cluster.gateways | ForEach-Object { "- $($_.fqdn) ($($_.ip):$($_.port))" } | Out-String)
"@

    Export-TermideskArtifacts -Section '08-gateway' -Files @{
        'gateway.yaml'     = $yaml
        'setup-guide.md'   = $guide
    }
}

function Export-TermideskNginxScripts {
    $s = Get-TermideskSettingsOrNew
    $gwLines = ($s.cluster.gateways | ForEach-Object { "     server $($_.ip):$($_.port);" }) -join "`n"
    $dispLines = ($s.cluster.dispatchers | ForEach-Object { "     server $($_.ip):443;" }) -join "`n"
    $siteConf = Expand-TermideskTemplateContent -Template (Read-TermideskTemplate 'nginx-site.conf.template') -Variables @{
        GATEWAY_UPSTREAMS = $gwLines; DISPATCHER_UPSTREAMS = $dispLines
    }

    $install = @"
#!/bin/bash
set -euo pipefail
FQDN="$($s.nginx.fqdn)"
sudo apt install -y nginx openssl
sudo openssl req -new -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $($s.nginx.keyPath) -out $($s.nginx.certPath) -subj "/CN=`$FQDN"
sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096
sudo mkdir -p /etc/nginx/snippets
echo 'ssl_certificate $($s.nginx.certPath); ssl_certificate_key $($s.nginx.keyPath);' | sudo tee /etc/nginx/snippets/self-signed.conf
cat <<'SITE' | sudo tee /etc/nginx/sites-available/`${FQDN}.conf
$siteConf
SITE
sudo ln -sf /etc/nginx/sites-available/`${FQDN}.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx
"@

    Export-TermideskArtifacts -Section '09-nginx' -Files @{
        '01-nginx-setup.sh' = $install
        'site.conf'         = $siteConf
    }
}

function Export-TermideskSslScripts {
    $s = Get-TermideskSettingsOrNew
    $ssl = $s.ssl

    $apache = @"
# Apache SSL — Termidesk 7.0
sudo cp <cert.pem> $($ssl.certFile)
sudo cp <key.pem> $($ssl.keyFile)
# В VirtualHost *:443:
SSLEngine on
SSLCertificateFile $($ssl.certFile)
SSLCertificateKeyFile $($ssl.keyFile)
$(if ($ssl.chainFile) { "SSLCertificateChainFile $($ssl.chainFile)" })
sudo systemctl restart apache2
"@

    $redirect = @"
# Принудительный HTTPS
<VirtualHost *:80>
    ServerName $($s.nginx.fqdn)
    Redirect permanent / https://$($s.nginx.fqdn)/
</VirtualHost>
"@

    $mtls = @"
MTLS_MODE='$($ssl.mtlsMode)'
MTLS_CONNECTIONS='all'
MTLS_CLIENT_CERT='/etc/opt/termidesk-vdi/mtls/client.crt'
MTLS_CLIENT_KEY='/etc/opt/termidesk-vdi/mtls/client.key'
MTLS_CLIENT_CA='/etc/opt/termidesk-vdi/mtls/ca.crt'
"@

    Export-TermideskArtifacts -Section '10-ssl' -Files @{
        'apache-ssl-setup.sh'    = $apache
        'https-redirect.conf'    = $redirect
        'termidesk.conf.mtls'    = $mtls
        'install-ca-guide.txt'   = "Док: $(Get-TermideskDocLink -Section ssl)"
    }
}

function Export-TermideskConfigToolScripts {
    $s = Get-TermideskSettingsOrNew
    $tc = $s.termideskConfig

    $guide = @"
# termidesk-config — интерактивная утилита Termidesk 7.0
cd /opt/termidesk/sbin/
sudo ./termidesk-config

Доступные разделы:
- Режим работы узла (TERMIDESK_FARM_MODE)
- Роли узла (NODE_ROLES): ADMIN, USER, CELERYMAN, TERMQ
- Способ хранения паролей (config/hvac/openbao)
- Тип установки СУБД (DB_CLUSTER_MODE)
- Настройка подключения к СУБД и RabbitMQ
- TermideskMQ клиент (TMQ_*)
- Fluentd / журналирование
- Сертификаты mTLS, Health Check, JWT Aggregator
- Перезапуск служб

После изменений всегда: «Перезапуск служб»
"@

    $conf = @"
LOG_LEVEL='$($tc.logLevel)'
LOG_DIR='$($tc.logDir)'
LANGUAGE_CODE='$($tc.languageCode)'
HEALTH_CHECK_ACCESS_KEY='$($tc.healthCheckAccessKey)'
METRICS_ACCESS_KEY='$($tc.metricsAccessKey)'
"@

    $apply = @"
#!/bin/bash
cd /opt/termidesk/sbin/
sudo ./termidesk-config
sudo systemctl restart termidesk-vdi
sudo systemctl restart termidesk-celery-beat termidesk-celery-worker 2>/dev/null || true
"@

    Export-TermideskArtifacts -Section '11-termidesk-config' -Files @{
        'guide.md'               = $guide
        'termidesk.conf.snippet' = $conf
        'apply-and-restart.sh'   = $apply
    }
}

function Edit-TermideskDispatcherWizard {
    $s = Get-TermideskSettingsOrNew
    $s.dispatcher.nodeName = Invoke-TermideskPrompt -Caption 'NODE_NAME' -Default $s.dispatcher.nodeName
    $s.dispatcher.nodeRoles = Invoke-TermideskPrompt -Caption 'NODE_ROLES (ADMIN,USER,...)' -Default $s.dispatcher.nodeRoles
    Save-TermideskSettings -Settings $s
    Export-TermideskDispatcherScripts
}

function Invoke-TermideskDispatcherMenu { Invoke-TermideskSubMenu -Title 'Универсальный диспетчер' -DocSection 'cluster' -Items @{
    '1' = @{ Label = 'Мастер настройки'; Action = { Edit-TermideskDispatcherWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты'; Action = { Export-TermideskDispatcherScripts } }
}}

function Invoke-TermideskCeleryMenu { Invoke-TermideskSubMenu -Title 'Менеджер рабочих мест' -DocSection 'cluster' -Items @{
    '1' = @{ Label = 'Сгенерировать скрипты установки'; Action = { Export-TermideskCeleryScripts } }
    '2' = @{ Label = 'Установить на узел (SSH)'; Action = {
        Export-TermideskCeleryScripts
        $s = Get-TermideskSettingsOrNew
        $node = $s.cluster.celeryManagers | Select-Object -First 1
        $script = Get-Content (Get-TermideskOutputPath '07-celery/01-install-celery.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $node.ip -ScriptContent $script
        Wait-TermideskKey
    }}
}}

function Invoke-TermideskGatewayMenu { Invoke-TermideskSubMenu -Title 'Termidesk Connect (Шлюз)' -DocSection 'gateway' -Items @{
    '1' = @{ Label = 'Сгенерировать gateway.yaml'; Action = { Export-TermideskGatewayScripts } }
    '2' = @{ Label = 'Показать инструкцию'; Action = { Export-TermideskGatewayScripts } }
}}

function Invoke-TermideskNginxMenu { Invoke-TermideskSubMenu -Title 'Балансировщик nginx' -DocSection 'distributed' -Items @{
    '1' = @{ Label = 'Сгенерировать конфигурацию'; Action = { Export-TermideskNginxScripts } }
    '2' = @{ Label = 'Установить nginx (SSH)'; Action = {
        Export-TermideskNginxScripts
        $s = Get-TermideskSettingsOrNew
        $host_ = Invoke-TermideskPrompt -Caption 'IP балансировщика' -Default $s.nginx.fqdn
        $script = Get-Content (Get-TermideskOutputPath '09-nginx/01-nginx-setup.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $host_ -ScriptContent $script
        Wait-TermideskKey
    }}
}}

function Invoke-TermideskSslMenu { Invoke-TermideskSubMenu -Title 'SSL/TLS и сертификаты' -DocSection 'ssl' -Items @{
    '1' = @{ Label = 'Сгенерировать скрипты Apache SSL'; Action = { Export-TermideskSslScripts } }
}}

function Invoke-TermideskConfigToolMenu { Invoke-TermideskSubMenu -Title 'termidesk-config' -DocSection 'termidesk-config' -Items @{
    '1' = @{ Label = 'Сгенерировать справку и конфиг'; Action = { Export-TermideskConfigToolScripts } }
    '2' = @{ Label = 'Применить и перезапустить (SSH)'; Action = {
        Export-TermideskConfigToolScripts
        $s = Get-TermideskSettingsOrNew
        $ref = $s.cluster.referenceNode.ip
        $script = Get-Content (Get-TermideskOutputPath '11-termidesk-config/apply-and-restart.sh') -Raw
        Invoke-TermideskOnNode -HostAddress $ref -ScriptContent $script
        Wait-TermideskKey
    }}
}}

Export-ModuleMember -Function @(
    'Invoke-TermideskDispatcherMenu','Invoke-TermideskCeleryMenu',
    'Invoke-TermideskGatewayMenu','Invoke-TermideskNginxMenu',
    'Invoke-TermideskSslMenu','Invoke-TermideskConfigToolMenu',
    'Export-TermideskDispatcherScripts','Export-TermideskCeleryScripts',
    'Export-TermideskGatewayScripts','Export-TermideskNginxScripts',
    'Export-TermideskSslScripts','Export-TermideskConfigToolScripts'
)
