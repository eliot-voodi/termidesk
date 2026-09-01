# Common helpers for Termidesk automation scripts

$Script:TermideskRoot = Split-Path -Parent $PSScriptRoot
$Script:TermideskOutput = Join-Path $Script:TermideskRoot 'output'
$Script:TermideskConfig = Join-Path $Script:TermideskRoot 'config'
$Script:TermideskTemplates = Join-Path $Script:TermideskRoot 'templates'

function Initialize-TermideskPaths {
    foreach ($path in @($Script:TermideskOutput, $Script:TermideskConfig)) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Get-TermideskConfigPath {
    param([string]$Name = 'termidesk-settings.json')
    Join-Path $Script:TermideskConfig $Name
}

function Get-TermideskClusterConfigPath {
    Join-Path $Script:TermideskConfig 'cluster-config.json'
}

function Get-TermideskOutputPath {
    param([string]$SubPath = '')
    if ($SubPath) {
        $full = Join-Path $Script:TermideskOutput $SubPath
        $dir = Split-Path $full -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        return $full
    }
    return $Script:TermideskOutput
}

function Read-TermideskSettings {
    param([string]$Path = (Get-TermideskConfigPath))
    if (-not (Test-Path $Path)) { return $null }
    Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-TermideskSettings {
    param(
        [Parameter(Mandatory)]
        $Settings,
        [string]$Path = (Get-TermideskConfigPath)
    )
    $json = $Settings | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Настройки сохранены: $Path" -ForegroundColor Green
    Sync-TermideskClusterConfig -Settings $Settings
}

function Sync-TermideskClusterConfig {
    param($Settings)
    if (-not $Settings.cluster) { return }
    $legacy = [PSCustomObject]@{
        version        = $Settings.version
        deploymentType = $Settings.cluster.deploymentType
        domain         = $Settings.environment.domain
        secretsStorage = $Settings.cluster.secretsStorage
        database       = $Settings.database
        rabbitmq       = $Settings.rabbitmq
        dispatchers    = $Settings.cluster.dispatchers
        celeryManagers = $Settings.cluster.celeryManagers
        gateways       = $Settings.cluster.gateways
        loadBalancers  = $Settings.cluster.loadBalancers
        ssh            = $Settings.ssh
        referenceNode  = $Settings.cluster.referenceNode
    }
    $json = $legacy | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText((Get-TermideskClusterConfigPath), $json, [System.Text.UTF8Encoding]::new($false))
}

function Read-TermideskConfig {
    $settings = Read-TermideskSettings
    if ($settings -and $settings.cluster) {
        return [PSCustomObject]@{
            version        = $settings.version
            deploymentType = $settings.cluster.deploymentType
            domain         = $settings.environment.domain
            secretsStorage = $settings.cluster.secretsStorage
            database       = $settings.database
            rabbitmq       = $settings.rabbitmq
            dispatchers    = $settings.cluster.dispatchers
            celeryManagers = $settings.cluster.celeryManagers
            gateways       = $settings.cluster.gateways
            loadBalancers  = $settings.cluster.loadBalancers
            ssh            = $settings.ssh
            referenceNode  = $settings.cluster.referenceNode
        }
    }
    $path = Get-TermideskClusterConfigPath
    if (-not (Test-Path $path)) { return $null }
    Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-TermideskConfig {
    param([Parameter(Mandatory)] $Config)
    $json = $Config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText((Get-TermideskClusterConfigPath), $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Конфигурация кластера сохранена.' -ForegroundColor Green
}

function Read-TermideskTemplate {
    param([Parameter(Mandatory)][string]$Name)
    $path = Join-Path $Script:TermideskTemplates $Name
    if (-not (Test-Path $path)) { throw "Шаблон не найден: $path" }
    Get-Content -Path $path -Raw -Encoding UTF8
}

function Write-TermideskFile {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Content
    )
    $fullPath = Get-TermideskOutputPath -SubPath $RelativePath
    # PowerShell 5.1 требует UTF-8 BOM для .ps1/.psm1 с кириллицей
    $useBom = $RelativePath -match '\.(ps1|psm1)$'
    [System.IO.File]::WriteAllText($fullPath, $Content, [System.Text.UTF8Encoding]::new($useBom))
    return $fullPath
}

function Expand-TermideskTemplateContent {
    param([string]$Template, [hashtable]$Variables)
    $result = $Template
    foreach ($key in $Variables.Keys) {
        $result = $result -replace "\{\{$key\}\}", [string]$Variables[$key]
    }
    return $result
}

function Invoke-TermideskPrompt {
    param(
        [Parameter(Mandatory)][string]$Caption,
        [string]$Default = '',
        [switch]$Secure,
        [switch]$AllowEmpty,
        [switch]$NoDefaultHint
    )
    if ($Secure) {
        $secureVal = Read-Host -Prompt $Caption -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureVal)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
    $prompt = if ($Default -and -not $NoDefaultHint) { "$Caption [$Default]" } else { $Caption }
    $value = Read-Host -Prompt $prompt
    if ([string]::IsNullOrWhiteSpace($value)) {
        if ($AllowEmpty) { return $(if ($Default -and -not $NoDefaultHint) { $Default } else { '' }) }
        if ($Default -and -not $NoDefaultHint) { return $Default }
        Write-Host '  Значение обязательно.' -ForegroundColor Yellow
        return Invoke-TermideskPrompt @PSBoundParameters
    }
    return $value.Trim()
}

function Invoke-TermideskPromptRequired {
    param([Parameter(Mandatory)][string]$Caption, [switch]$Secure, [string]$Hint = '')
    if ($Hint) { Write-Host "  $Hint" -ForegroundColor DarkGray }
    do {
        $v = Invoke-TermideskPrompt -Caption $Caption -Secure:$Secure -NoDefaultHint
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        Write-Host '  Поле обязательно для заполнения.' -ForegroundColor Yellow
    } while ($true)
}

function Invoke-TermideskPromptOptional {
    param([Parameter(Mandatory)][string]$Caption, [switch]$Secure, [string]$Hint = '')
    if ($Hint) { Write-Host "  $Hint" -ForegroundColor DarkGray }
    return Invoke-TermideskPrompt -Caption $Caption -Secure:$Secure -AllowEmpty -Default '' -NoDefaultHint
}

function Invoke-TermideskPromptNode {
    param(
        [Parameter(Mandatory)][string]$RoleLabel,
        [int]$Index,
        [switch]$MarkReference
    )
    Write-Host "  --- $RoleLabel #$Index ---" -ForegroundColor DarkGray
    $node = [ordered]@{}
    $node.name = Invoke-TermideskPromptRequired -Caption '  NODE_NAME (уникальное имя узла)'
    $node.fqdn = Invoke-TermideskPromptRequired -Caption '  FQDN'
    $node.ip   = Invoke-TermideskPromptRequired -Caption '  IP-адрес'
    if ($MarkReference) { $node.isReference = $true }
    return [PSCustomObject]$node
}

function Invoke-TermideskPromptInt {
    param(
        [Parameter(Mandatory)][string]$Caption,
        [int]$Minimum = 1,
        [int]$Maximum = 255
    )
    do {
        $raw = Invoke-TermideskPromptRequired -Caption $Caption
        if ($raw -match '^\d+$') {
            $n = [int]$raw
            if ($n -ge $Minimum -and $n -le $Maximum) { return $n }
        }
        Write-Host "  Введите число от $Minimum до $Maximum." -ForegroundColor Yellow
    } while ($true)
}

function Test-TermideskIpOrFqdn {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value -match '^(\d{1,3}\.){3}\d{1,3}$' -or $Value -match '^[a-zA-Z0-9][a-zA-Z0-9\.\-]*[a-zA-Z0-9]$'
}

function Confirm-TermideskAction {
    param([string]$Message = 'Продолжить?')
    return (Read-Host "$Message (y/N)") -match '^[yYдД]'
}

function Show-TermideskStepHeader {
    param([int]$Step, [int]$Total, [string]$Title)
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
    Write-Host " Шаг $Step/$Total : $Title" -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
    Write-Host ''
}

function Get-TermideskSshParams {
    $s = Read-TermideskSettings
    if (-not $s) { return @{ User = 'admin'; Port = 22; KeyPath = '' } }
    return @{ User = $s.ssh.user; Port = [int]$s.ssh.port; KeyPath = $s.ssh.keyPath }
}

function Invoke-TermideskRemoteScript {
    param(
        [Parameter(Mandatory)][string]$HostAddress,
        [Parameter(Mandatory)][string]$ScriptPath,
        [string]$User,
        [int]$Port = 22,
        [string]$KeyPath = ''
    )
    if (-not (Test-Path $ScriptPath)) { throw "Скрипт не найден: $ScriptPath" }
    $sshTarget = if ($User) { "${User}@${HostAddress}" } else { $HostAddress }
    $sshArgs = @('-p', $Port, '-o', 'StrictHostKeyChecking=accept-new')
    $scpArgs = @('-P', $Port, '-o', 'StrictHostKeyChecking=accept-new')
    if ($KeyPath -and (Test-Path $KeyPath)) {
        $sshArgs += @('-i', $KeyPath)
        $scpArgs += @('-i', $KeyPath)
    }
    $remotePath = "/tmp/$(Split-Path $ScriptPath -Leaf)"
    Write-Host "Копирование на $sshTarget ..." -ForegroundColor Gray
    & scp @scpArgs $ScriptPath "${sshTarget}:${remotePath}"
    if ($LASTEXITCODE -ne 0) { throw "scp завершился с кодом $LASTEXITCODE" }
    Write-Host "Выполнение на $sshTarget ..." -ForegroundColor Gray
    & ssh @sshArgs $sshTarget "sudo bash $remotePath"
    return $LASTEXITCODE
}

function Invoke-TermideskOnNode {
    param(
        [Parameter(Mandatory)][string]$HostAddress,
        [Parameter(Mandatory)][string]$ScriptContent,
        [string]$ScriptName = 'termidesk-task.sh'
    )
    $tempScript = Join-Path $env:TEMP $ScriptName
    [System.IO.File]::WriteAllText($tempScript, $ScriptContent, [System.Text.UTF8Encoding]::new($false))
    $ssh = Get-TermideskSshParams
    try {
        return Invoke-TermideskRemoteScript -HostAddress $HostAddress -ScriptPath $tempScript `
            -User $ssh.User -Port $ssh.Port -KeyPath $ssh.KeyPath
    }
    finally {
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    }
}

function Export-TermideskArtifacts {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][hashtable]$Files
    )
    $written = @()
    foreach ($entry in $Files.GetEnumerator()) {
        $written += Write-TermideskFile -RelativePath "$Section/$($entry.Key)" -Content $entry.Value
    }
    Write-Host "[$Section] Сгенерировано: $($written.Count) файлов" -ForegroundColor Green
    return $written
}

function Enable-TermideskTlsBypass {
    if (-not ('TrustAllCerts' -as [type])) {
        Add-Type @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class TrustAllCerts : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int cp) { return true; }
}
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCerts
    }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

function Connect-TermideskPortal {
    param([string]$Url, [string]$User, [string]$Password, [switch]$VerifySsl)
    $settings = Read-TermideskSettings
    if (-not $Url -and $settings) { $Url = $settings.portal.url }
    if (-not $User -and $settings) { $User = $settings.portal.adminUser }
    if (-not $Password -and $settings) { $Password = $settings.portal.adminPassword }
    if (-not $Url -or -not $User) { throw 'Не задан URL портала или пользователь.' }

    $baseUrl = $Url.TrimEnd('/')
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    if (-not $VerifySsl) { Enable-TermideskTlsBypass }

    $body = @{ username = $User; password = $Password } | ConvertTo-Json
    $loginUrls = @(
        "$baseUrl/api/auth/login/",
        "$baseUrl/termidesk/api/auth/login/",
        "$baseUrl/api/v1/auth/login/"
    )
    $lastError = $null
    foreach ($loginUrl in $loginUrls) {
        try {
            $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body `
                -ContentType 'application/json' -WebSession $session -ErrorAction Stop
            return [PSCustomObject]@{
                BaseUrl = $baseUrl; Session = $session; Token = $response.token; Response = $response
            }
        }
        catch { $lastError = $_ }
    }
    throw "Не удалось авторизоваться на $baseUrl : $lastError"
}

function Invoke-TermideskPortalApi {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Endpoint,
        $Body = $null,
        $Connection = $null
    )
    if (-not $Connection) { $Connection = Connect-TermideskPortal }
    $params = @{
        Uri = "$($Connection.BaseUrl)$Endpoint"
        Method = $Method
        WebSession = $Connection.Session
        ContentType = 'application/json'
    }
    if ($Connection.Token) { $params.Headers = @{ Authorization = "Bearer $($Connection.Token)" } }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 8) }
    return Invoke-RestMethod @params
}

function Get-TermideskDocLink {
    param([string]$Section = '')
    $base = 'https://termidesk.ru/docs/ru-termidesk-doc/v7.0'
    switch ($Section) {
        'cluster'          { return "$base/documentation/termidesk-install/install-delete/alse.html" }
        'distributed'      { return "$base/documentation/termidesk-settings/settings/distributed-config.html" }
        'termidesk-config' { return "$base/documentation/termidesk-settings/cli/termidesk-config.html" }
        'prepare'          { return "$base/documentation/termidesk-install/install-delete/prepare-environment.html" }
        'architecture'     { return "$base/architecture/architecture.html" }
        'openbao'          { return "$base/documentation/termidesk-settings/settings/openbao.html" }
        'domains'          { return "$base/documentation/termidesk-settings/domains/add-domain.html" }
        'providers'        { return "$base/documentation/termidesk-settings/providers/add-provider.html" }
        'pools'            { return "$base/documentation/termidesk-settings/pools/add-pool.html" }
        'aggregator'       { return "$base/documentation/aggregator/install-delete/alse.html" }
        'backup'           { return "$base/documentation/termidesk-settings/backup-recovery/actions.html" }
        'logging'          { return "$base/documentation/termidesk-settings/logging/system-settings.html" }
        'audit'            { return "$base/documentation/termidesk-settings/audit/audit-settings.html" }
        'healthcheck'      { return "$base/documentation/termidesk-settings/monitoring-notifications/healthcheck.html" }
        'zabbix'           { return "$base/documentation/termidesk-settings/monitoring-notifications/zabbix.html" }
        'ssl'              { return "$base/documentation/termidesk-settings/settings/replace-ssl-apache.html" }
        'gateway'          { return "$base/documentation/gateway/settings/config-files.html" }
        default            { return "$base/index.html" }
    }
}

function Invoke-TermideskSubMenu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable]$Items,
        [string]$DocSection = ''
    )
    do {
        Show-TermideskBanner
        Write-Host "  $Title" -ForegroundColor Yellow
        if ($DocSection) {
            Write-Host "  Док: $(Get-TermideskDocLink -Section $DocSection)" -ForegroundColor DarkGray
        }
        Write-Host ''
        foreach ($key in ($Items.Keys | Sort-Object)) {
            Write-Host "  [$key]  $($Items[$key].Label)"
        }
        Write-Host '  [0]  Назад'
        Write-Host ''
        $choice = Read-Host '  Выбор'
        if ($choice -eq '0') { return }
        if ($Items.ContainsKey($choice)) {
            & $Items[$choice].Action
        }
        else {
            Write-Host '  Неверный выбор.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    } while ($true)
}

function Get-TermideskHaTemplatePath {
    Join-Path $Script:TermideskConfig 'ha-cluster.template.json'
}

function Import-TermideskSettingsFile {
    <#
    .SYNOPSIS
        Загружает JSON настроек в config/termidesk-settings.json
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Force
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Файл не найден: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        $settings = $raw | ConvertFrom-Json
    }
    catch {
        throw "Некорректный JSON: $Path — $_"
    }
    if (-not $settings.cluster -or -not $settings.database) {
        throw 'В файле нет обязательных секций cluster / database. Используйте config/ha-cluster.template.json'
    }
    $dest = Get-TermideskConfigPath
    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        if (-not (Confirm-TermideskAction -Message "Перезаписать $dest ?")) {
            Write-Host 'Импорт отменён.' -ForegroundColor Yellow
            return $null
        }
    }
    Initialize-TermideskPaths
    # убираем служебное поле шаблона из рабочей копии
    if ($settings.PSObject.Properties.Name -contains '_template') {
        $settings.PSObject.Properties.Remove('_template')
    }
    Save-TermideskSettings -Settings $settings
    Write-Host "Импортировано: $Path → $dest" -ForegroundColor Green
    return $settings
}

function Test-TermideskHaSettingsComplete {
    <#
    .SYNOPSIS
        Проверяет, что в настройках HA не осталось плейсхолдеров __ЗАПОЛНИТЕ__ и пустых обязательных полей.
    #>
    param($Settings)
    if (-not $Settings) { $Settings = Read-TermideskSettings }
    if (-not $Settings) { return ,@('Файл termidesk-settings.json не найден') }

    $errors = New-Object System.Collections.Generic.List[string]
    function Add-Err([string]$Msg) { [void]$errors.Add($Msg) }
    function Test-Val($Value, [string]$Path) {
        if ($null -eq $Value) { Add-Err "$Path — пусто"; return }
        $s = [string]$Value
        if ([string]::IsNullOrWhiteSpace($s)) { Add-Err "$Path — пусто"; return }
        if ($s -match '__ЗАПОЛНИТЕ') { Add-Err "$Path — остался плейсхолдер: $s" }
    }

    Test-Val $Settings.environment.domain 'environment.domain'
    Test-Val $Settings.environment.ntpServer 'environment.ntpServer'
    Test-Val $Settings.environment.termideskRepo 'environment.termideskRepo'
    Test-Val $Settings.ssh.user 'ssh.user'
    Test-Val $Settings.database.host1 'database.host1'
    Test-Val $Settings.database.name 'database.name'
    Test-Val $Settings.database.user 'database.user'
    Test-Val $Settings.database.password 'database.password'
    Test-Val $Settings.database.pgHbaNetwork 'database.pgHbaNetwork'
    Test-Val $Settings.rabbitmq.host 'rabbitmq.host'
    Test-Val $Settings.rabbitmq.user 'rabbitmq.user'
    Test-Val $Settings.rabbitmq.password 'rabbitmq.password'
    Test-Val $Settings.portal.url 'portal.url'
    Test-Val $Settings.portal.adminUser 'portal.adminUser'
    Test-Val $Settings.portal.adminPassword 'portal.adminPassword'
    Test-Val $Settings.cluster.loadBalancers.fqdn 'cluster.loadBalancers.fqdn'
    Test-Val $Settings.cluster.tls.certPath 'cluster.tls.certPath'
    Test-Val $Settings.cluster.tls.keyPath 'cluster.tls.keyPath'
    Test-Val $Settings.cluster.tls.dhparamPath 'cluster.tls.dhparamPath'
    Test-Val $Settings.cluster.tls.dnsResolverPrimary 'cluster.tls.dnsResolverPrimary'
    Test-Val $Settings.monitoring.healthCheckAccessKey 'monitoring.healthCheckAccessKey'
    Test-Val $Settings.gateway.coordinatorUrl 'gateway.coordinatorUrl'
    Test-Val $Settings.gateway.coordinatorUser 'gateway.coordinatorUser'
    Test-Val $Settings.gateway.coordinatorPass 'gateway.coordinatorPass'

    if (-not $Settings.cluster.dispatchers -or @($Settings.cluster.dispatchers).Count -lt 2) {
        Add-Err 'cluster.dispatchers — нужно минимум 2 узла'
    }
    else {
        $i = 0
        foreach ($d in @($Settings.cluster.dispatchers)) {
            Test-Val $d.name "cluster.dispatchers[$i].name"
            Test-Val $d.fqdn "cluster.dispatchers[$i].fqdn"
            Test-Val $d.ip "cluster.dispatchers[$i].ip"
            $i++
        }
    }
    if (-not $Settings.cluster.gateways -or @($Settings.cluster.gateways).Count -lt 2) {
        Add-Err 'cluster.gateways — нужно минимум 2 узла'
    }
    if ($Settings.cluster.deploymentType -eq 'standard') {
        if (-not $Settings.cluster.celeryManagers -or @($Settings.cluster.celeryManagers).Count -lt 2) {
            Add-Err 'cluster.celeryManagers — для standard нужно минимум 2 узла'
        }
    }
    if (-not $Settings.cluster.loadBalancers.nodes -or @($Settings.cluster.loadBalancers.nodes).Count -lt 1) {
        Add-Err 'cluster.loadBalancers.nodes — нужен хотя бы 1 балансировщик'
    }

    return ,$errors.ToArray()
}

function Show-TermideskHaSettingsValidation {
    param($Settings)
    $errs = Test-TermideskHaSettingsComplete -Settings $Settings
    if (-not $errs -or $errs.Count -eq 0) {
        Write-Host 'Проверка JSON: обязательные поля заполнены.' -ForegroundColor Green
        return $true
    }
    Write-Host "Проверка JSON: найдено проблем — $($errs.Count)" -ForegroundColor Yellow
    foreach ($e in $errs) { Write-Host "  • $e" -ForegroundColor Red }
    return $false
}

Export-ModuleMember -Function @(
    'Initialize-TermideskPaths','Get-TermideskConfigPath','Get-TermideskClusterConfigPath',
    'Get-TermideskOutputPath','Read-TermideskSettings','Save-TermideskSettings',
    'Sync-TermideskClusterConfig','Read-TermideskConfig','Save-TermideskConfig',
    'Read-TermideskTemplate','Write-TermideskFile','Expand-TermideskTemplateContent',
    'Invoke-TermideskPrompt','Invoke-TermideskPromptRequired','Invoke-TermideskPromptOptional',
    'Invoke-TermideskPromptNode','Invoke-TermideskPromptInt',
    'Show-TermideskStepHeader','Get-TermideskSshParams','Invoke-TermideskRemoteScript',
    'Invoke-TermideskOnNode','Export-TermideskArtifacts','Enable-TermideskTlsBypass',
    'Connect-TermideskPortal','Invoke-TermideskPortalApi','Get-TermideskDocLink',
    'Invoke-TermideskSubMenu','Confirm-TermideskAction',
    'Get-TermideskHaTemplatePath','Import-TermideskSettingsFile',
    'Test-TermideskHaSettingsComplete','Show-TermideskHaSettingsValidation'
)
Export-ModuleMember -Variable TermideskRoot, TermideskOutput, TermideskConfig, TermideskTemplates
