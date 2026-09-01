# Termidesk 7.0 — портал (пункты 12–14): домены, поставщики, фонды, агрегатор

function Get-TermideskSettingsOrNew {
    $s = Read-TermideskSettings
    if ($s) { return $s }
    Copy-Item (Join-Path $Script:TermideskConfig 'termidesk-settings.example.json') (Get-TermideskConfigPath) -Force
    return Read-TermideskSettings
}

function Add-TermideskDomainWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'Домен аутентификации'
    $domain = [PSCustomObject]@{
        name         = Invoke-TermideskPrompt -Caption 'Имя домена'
        type         = Invoke-TermideskPrompt -Caption 'Тип (ActiveDirectory/LDAP/SAML/Internal)' -Default 'ActiveDirectory'
        host         = Invoke-TermideskPrompt -Caption 'Хост LDAP/AD'
        port         = [int](Invoke-TermideskPrompt -Caption 'Порт' -Default '389')
        baseDn       = Invoke-TermideskPrompt -Caption 'Base DN' -Default '' -AllowEmpty
        bindUser     = Invoke-TermideskPrompt -Caption 'Bind User' -Default '' -AllowEmpty
        bindPassword = Invoke-TermideskPrompt -Caption 'Bind Password' -Secure
        useSsl       = (Read-Host 'Использовать SSL? (y/N)') -match '^[yY]'
    }
    $list = @($s.domains) + @($domain)
    $s.domains = $list
    Save-TermideskSettings -Settings $s
    Export-TermideskDomainScripts
}

function Export-TermideskDomainScripts {
    $s = Get-TermideskSettingsOrNew
    $apiScript = @'
# Создание домена через REST API Termidesk
param([string]$PortalUrl, [string]$User, [string]$Password)
Import-Module "$PSScriptRoot\..\..\modules\Termidesk.Common.psm1" -Force
$conn = Connect-TermideskPortal -Url $PortalUrl -User $User -Password $Password
'@
    foreach ($d in $s.domains) {
        $payload = $d | ConvertTo-Json -Depth 4
        $apiScript += @"

# Домен: $($d.name)
`$body = @'
$payload
'@ | ConvertFrom-Json
# POST /api/authenticators/ или через портал: Аутентификация -> Домены -> Добавить
Write-Host "Добавьте домен '$($d.name)' ($($d.type)) через портал или API"
"@
    }

    $manual = @"
# Ручная настройка доменов — Портал администратора
# $(Get-TermideskDocLink -Section domains)
# Путь: Аутентификация -> Домены -> [Добавить]

$($s.domains | ForEach-Object {
"- $($_.name) | $($_.type) | $($_.host):$($_.port) | SSL=$($_.useSsl)"
} | Out-String)
"@

    Export-TermideskArtifacts -Section '12-domains' -Files @{
        'add-domains-api.ps1' = $apiScript
        'domains-manual.md'   = $manual
        'domains.json'        = ($s.domains | ConvertTo-Json -Depth 5)
    }
}

function Add-TermideskProviderWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'Поставщик ресурсов'
    $provider = [PSCustomObject]@{
        name      = Invoke-TermideskPrompt -Caption 'Имя поставщика'
        type      = Invoke-TermideskPrompt -Caption 'Тип (oVirt/zVirt/VMmanager/Brest/...)' -Default 'oVirt'
        host      = Invoke-TermideskPrompt -Caption 'URL/API хост'
        port      = [int](Invoke-TermideskPrompt -Caption 'Порт' -Default '443')
        username  = Invoke-TermideskPrompt -Caption 'Пользователь'
        password  = Invoke-TermideskPrompt -Caption 'Пароль' -Secure
        verifySsl = -not ((Read-Host 'Отключить проверку SSL? (Y/n)') -match '^[nN]')
    }
    $list = @($s.providers) + @($provider)
    $s.providers = $list
    Save-TermideskSettings -Settings $s
    Export-TermideskProviderScripts
}

function Export-TermideskProviderScripts {
    $s = Get-TermideskSettingsOrNew
    $guide = @"
# Поставщики ресурсов — Termidesk 7.0
# $(Get-TermideskDocLink -Section providers)

Портал: Инфраструктура -> Поставщики ресурсов -> Добавить

$($s.providers | ForEach-Object {
@"
---
Имя: $($_.name)
Тип: $($_.type)
Хост: $($_.host):$($_.port)
Пользователь: $($_.username)
Verify SSL: $($_.verifySsl)
"@
} | Out-String)

Создайте сервисную учётную запись на платформе виртуализации.
"@

    Export-TermideskArtifacts -Section '13-providers' -Files @{
        'providers-manual.md' = $guide
        'providers.json'      = ($s.providers | ConvertTo-Json -Depth 5)
    }
}

function Add-TermideskPoolWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'Фонд рабочих мест VDI'
    $pool = [PSCustomObject]@{
        name         = Invoke-TermideskPrompt -Caption 'Имя фонда'
        providerName = Invoke-TermideskPrompt -Caption 'Поставщик' -Default ($s.providers[0].name)
        templateName = Invoke-TermideskPrompt -Caption 'Шаблон РМ'
        maxDesktops  = [int](Invoke-TermideskPrompt -Caption 'Макс. РМ' -Default '10')
        minDesktops  = [int](Invoke-TermideskPrompt -Caption 'Мин. РМ' -Default '2')
        protocol     = Invoke-TermideskPrompt -Caption 'Протокол (TERA/RDP/...)' -Default 'TERA'
        network      = Invoke-TermideskPrompt -Caption 'Сеть' -Default 'default'
    }
    $list = @($s.pools) + @($pool)
    $s.pools = $list
    Save-TermideskSettings -Settings $s
    Export-TermideskPoolScripts
}

function Export-TermideskPoolScripts {
    $s = Get-TermideskSettingsOrNew
    $sequence = @"
# Последовательность настройки VDI — Termidesk 7.0
# $(Get-TermideskDocLink -Section pools)

1. Подготовить шаблон ВМ на платформе виртуализации
2. Добавить поставщик ресурсов
3. Создать шаблон РМ в Termidesk
4. Настроить параметры гостевой ОС
5. Добавить протоколы доставки
6. Добавить сети
7. Создать фонд РМ:
$($s.pools | ForEach-Object {
"   - $($_.name): поставщик=$($_.providerName), шаблон=$($_.templateName), $($_.minDesktops)-$($_.maxDesktops) РМ, протокол=$($_.protocol)"
} | Out-String)
8. Назначить группы, протоколы, сети
9. Опубликовать фонд
"@

    Export-TermideskArtifacts -Section '13-pools' -Files @{
        'vdi-setup-sequence.md' = $sequence
        'pools.json'            = ($s.pools | ConvertTo-Json -Depth 5)
    }
}

function Edit-TermideskAggregatorWizard {
    $s = Get-TermideskSettingsOrNew
    Show-TermideskStepHeader -Step 1 -Total 1 -Title 'Агрегатор'
    $s.aggregator.enabled = (Read-Host 'Установить Агрегатор? (y/N)') -match '^[yY]'
    if ($s.aggregator.enabled) {
        $s.aggregator.url = Invoke-TermideskPrompt -Caption 'URL агрегатора' -Default $s.aggregator.url
        $s.aggregator.nodeName = Invoke-TermideskPrompt -Caption 'NODE_NAME' -Default $s.aggregator.nodeName
        $s.aggregator.database.host = Invoke-TermideskPrompt -Caption 'БД хост (отдельная!)' -Default $s.aggregator.database.host
        $s.aggregator.database.name = Invoke-TermideskPrompt -Caption 'Имя БД' -Default $s.aggregator.database.name
        $s.aggregator.mappingYaml = Invoke-TermideskPrompt -Caption 'mapping.yaml' -Default $s.aggregator.mappingYaml
    }
    Save-TermideskSettings -Settings $s
    Export-TermideskAggregatorScripts
}

function Export-TermideskAggregatorScripts {
    $s = Get-TermideskSettingsOrNew
    $a = $s.aggregator

    $install = @"
#!/bin/bash
# Агрегатор Termidesk — отдельный узел, отдельная БД!
set -euo pipefail
sudo apt install -y termidesk-vdi
# termidesk-config: TERMIDESK_FARM_MODE=aggregator, NODE_ROLES=ADMIN,USER
TERMIDESK_FARM_MODE='aggregator'
NODE_NAME='$($a.nodeName)'
DBHOST='$($a.database.host)'
DBNAME='$($a.database.name)'
"@

    $mapping = @"
# mapping.yaml — сопоставление NODE_NAME и FQDN
$($s.cluster.dispatchers | ForEach-Object { "$($_.name): $($_.fqdn)" } | Out-String)
"@

    $jwt = @"
# JWT сертификаты Агрегатора (на узле Агрегатора)
AGGREGATOR_JWT_SSL_KEY='/etc/opt/termidesk-vdi/jwt/key.pem'
# На Универсальном диспетчере (расшифровка):
AGGREGATOR_JWT_SSL_CERT='/etc/opt/termidesk-vdi/jwt/cert.pem'
AGGREGATOR_JWT_SSL_CERT_SECOND='/etc/opt/termidesk-vdi/jwt/cert-second.pem'
"@

    Export-TermideskArtifacts -Section '14-aggregator' -Files @{
        '01-install-aggregator.sh' = $install
        'mapping.yaml'             = $mapping
        'jwt-certificates.md'      = $jwt
        'README.txt'               = "Док: $(Get-TermideskDocLink -Section aggregator)"
    }
}

function Invoke-TermideskPortalApiTest {
    try {
        $conn = Connect-TermideskPortal
        Write-Host "Подключение OK: $($conn.BaseUrl)" -ForegroundColor Green
    }
    catch {
        Write-Host "Ошибка: $_" -ForegroundColor Red
        Write-Host 'Проверьте portal.url, adminUser, adminPassword в termidesk-settings.json' -ForegroundColor Yellow
    }
}

function Invoke-TermideskDomainsMenu { Invoke-TermideskSubMenu -Title 'Домены и аутентификация' -DocSection 'domains' -Items @{
    '1' = @{ Label = 'Добавить домен (мастер)'; Action = { Add-TermideskDomainWizard } }
    '2' = @{ Label = 'Экспорт конфигурации доменов'; Action = { Export-TermideskDomainScripts } }
    '3' = @{ Label = 'Проверить подключение к порталу'; Action = { Invoke-TermideskPortalApiTest } }
}}

function Invoke-TermideskProvidersMenu { Invoke-TermideskSubMenu -Title 'Поставщики ресурсов' -DocSection 'providers' -Items @{
    '1' = @{ Label = 'Добавить поставщик (мастер)'; Action = { Add-TermideskProviderWizard } }
    '2' = @{ Label = 'Экспорт конфигурации'; Action = { Export-TermideskProviderScripts } }
}}

function Invoke-TermideskPoolsMenu { Invoke-TermideskSubMenu -Title 'Фонды VDI' -DocSection 'pools' -Items @{
    '1' = @{ Label = 'Добавить фонд (мастер)'; Action = { Add-TermideskPoolWizard } }
    '2' = @{ Label = 'Экспорт последовательности настройки VDI'; Action = { Export-TermideskPoolScripts } }
    '3' = @{ Label = 'Поставщики'; Action = { Invoke-TermideskProvidersMenu } }
}}

function Invoke-TermideskAggregatorMenu { Invoke-TermideskSubMenu -Title 'Агрегатор' -DocSection 'aggregator' -Items @{
    '1' = @{ Label = 'Мастер настройки Агрегатора'; Action = { Edit-TermideskAggregatorWizard } }
    '2' = @{ Label = 'Сгенерировать скрипты и mapping.yaml'; Action = { Export-TermideskAggregatorScripts } }
}}

Export-ModuleMember -Function @(
    'Invoke-TermideskDomainsMenu','Invoke-TermideskProvidersMenu',
    'Invoke-TermideskPoolsMenu','Invoke-TermideskAggregatorMenu',
    'Add-TermideskDomainWizard','Add-TermideskProviderWizard',
    'Add-TermideskPoolWizard','Export-TermideskDomainScripts',
    'Export-TermideskProviderScripts','Export-TermideskPoolScripts',
    'Export-TermideskAggregatorScripts'
)
