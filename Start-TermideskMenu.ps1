#Requires -Version 5.1
<#
.SYNOPSIS
    Termidesk VDI 7.0 — полная панель администрирования
.DESCRIPTION
    Интерактивное меню для настройки всех компонентов Termidesk 7.0.
    Можно сразу загрузить предзаполненный JSON (шаблон config/ha-cluster.template.json).
.EXAMPLE
    .\Start-TermideskMenu.ps1
.EXAMPLE
    .\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json
.EXAMPLE
    .\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -GenerateHa
.EXAMPLE
    .\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -HaWizard
.EXAMPLE
    .\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -GenerateHa -SkipMenu
#>

[CmdletBinding()]
param(
    # Путь к предзаполненному JSON (копия/заполнение config/ha-cluster.template.json)
    [string]$SettingsFile = '',
    # После импорта открыть меню [18] HA-кластера
    [switch]$HaWizard,
    # После импорта сразу сгенерировать output/18-ha-wizard/
    [switch]$GenerateHa,
    # Не открывать главное меню (имеет смысл с -GenerateHa)
    [switch]$SkipMenu,
    # Не спрашивать подтверждение перезаписи termidesk-settings.json
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot
$modulesPath = Join-Path $ScriptRoot 'modules'

Import-Module (Join-Path $modulesPath 'Termidesk.Common.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.UI.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.Cluster.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.Infrastructure.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.Components.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.Portal.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.Operations.psm1') -Force
Import-Module (Join-Path $modulesPath 'Termidesk.HaWizard.psm1') -Force

Initialize-TermideskPaths

function Initialize-TermideskSettingsIfMissing {
    $path = Get-TermideskConfigPath
    if (-not (Test-Path $path)) {
        $example = Join-Path $ScriptRoot 'config\termidesk-settings.example.json'
        if (Test-Path $example) {
            Copy-Item $example $path -Force
            Write-Host "Создан $path из example. Отредактируйте параметры." -ForegroundColor Yellow
        }
    }
}

function Invoke-TermideskSettingsMenu {
    Invoke-TermideskSubMenu -Title 'Управление конфигурацией' -Items @{
        '1' = @{ Label = 'Показать termidesk-settings.json'; Action = {
            $cfg = Read-TermideskSettings
            if ($cfg) { $cfg | ConvertTo-Json -Depth 10 | Write-Host }
            else { Write-Host 'Файл не найден.' -ForegroundColor Yellow }
            Wait-TermideskKey
        }}
        '2' = @{ Label = 'Загрузить из example'; Action = {
            Copy-Item (Join-Path $ScriptRoot 'config\termidesk-settings.example.json') (Get-TermideskConfigPath) -Force
            Write-Host 'Загружен example. Задайте пароли и IP.' -ForegroundColor Green
            Wait-TermideskKey
        }}
        '3' = @{ Label = 'Мастер: базовые параметры (домен, SSH, портал)'; Action = {
            $s = Read-TermideskSettings
            if (-not $s) { Initialize-TermideskSettingsIfMissing; $s = Read-TermideskSettings }
            $s.environment.domain = Invoke-TermideskPrompt -Caption 'Домен' -Default $s.environment.domain
            $s.portal.url = Invoke-TermideskPrompt -Caption 'URL портала администратора' -Default $s.portal.url
            $s.portal.adminUser = Invoke-TermideskPrompt -Caption 'Admin user' -Default $s.portal.adminUser
            $s.portal.adminPassword = Invoke-TermideskPrompt -Caption 'Admin password' -Secure
            $s.ssh.user = Invoke-TermideskPrompt -Caption 'SSH user' -Default $s.ssh.user
            Save-TermideskSettings -Settings $s
            Wait-TermideskKey
        }}
        '4' = @{ Label = 'Сгенерировать ВСЕ артефакты (output/)'; Action = { Export-TermideskAllArtifacts } }
        '5' = @{ Label = 'Экспорт только HA-кластера'; Action = {
            Export-TermideskClusterArtifacts
            Wait-TermideskKey
        }}
        '6' = @{ Label = 'Загрузить предзаполненный JSON / шаблон HA'; Action = {
            Invoke-TermideskHaImportFromFileInteractive
        }}
        '7' = @{ Label = 'Проверить заполненность HA JSON'; Action = {
            $null = Show-TermideskHaSettingsValidation
            Wait-TermideskKey
        }}
    }
}

function Import-TermideskStartupSettings {
    param([string]$Path, [switch]$ForceImport)
    if (-not $Path) { return $null }
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path $ScriptRoot $Path
    }
    Write-Host "Загрузка настроек: $Path" -ForegroundColor Cyan
    $settings = Import-TermideskSettingsFile -Path $Path -Force:$ForceImport
    if ($settings) {
        $null = Show-TermideskHaSettingsValidation -Settings $settings
    }
    return $settings
}

function Start-TermideskMenu {
    param([switch]$OpenHaWizard)

    if (-not $SettingsFile) {
        Initialize-TermideskSettingsIfMissing
    }

    if ($OpenHaWizard) {
        Invoke-TermideskHaWizardMenuLoop
    }

    do {
        Show-TermideskMainMenu
        $choice = Read-Host '  Выбор'

        switch ($choice.ToUpper()) {
            '1'  { Invoke-TermideskClusterMenuLoop }
            '18' { Invoke-TermideskHaWizardMenuLoop }
            '2'  { Invoke-TermideskPrepareMenu }
            '3'  { Invoke-TermideskDatabaseMenu }
            '4'  { Invoke-TermideskRabbitMqMenu }
            '5'  { Invoke-TermideskOpenBaoMenu }
            '6'  { Invoke-TermideskDispatcherMenu }
            '7'  { Invoke-TermideskCeleryMenu }
            '8'  { Invoke-TermideskGatewayMenu }
            '9'  { Invoke-TermideskNginxMenu }
            '10' { Invoke-TermideskSslMenu }
            '11' { Invoke-TermideskConfigToolMenu }
            '12' { Invoke-TermideskDomainsMenu }
            '13' { Invoke-TermideskPoolsMenu }
            '14' { Invoke-TermideskAggregatorMenu }
            '15' { Invoke-TermideskMonitoringMenu }
            '16' { Invoke-TermideskBackupMenu }
            '17' { Invoke-TermideskLoggingMenu }
            'C'  { Invoke-TermideskSettingsMenu }
            'A'  { Export-TermideskAllArtifacts }
            'O'  {
                $out = Get-TermideskOutputPath
                if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }
                Start-Process explorer.exe $out
            }
            'D'  { Show-TermideskDocLinks }
            'H'  { Show-TermideskInstruction }
            '0'  {
                Clear-Host
                Write-Host 'До свидания.' -ForegroundColor Cyan
                return
            }
            default {
                Write-Host '  Неверный выбор.' -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

# --- Точка входа ---
$imported = $null
if ($SettingsFile) {
    $imported = Import-TermideskStartupSettings -Path $SettingsFile -ForceImport:$Force
    if (-not $imported -and -not $Force) {
        # пользователь отказался от перезаписи — всё равно можно открыть меню
        Write-Host 'Продолжение без импорта.' -ForegroundColor Yellow
    }
}

if ($GenerateHa) {
    $s = Read-TermideskSettings
    if (-not $s) { throw 'Нет termidesk-settings.json — укажите -SettingsFile или заполните конфиг.' }
    Export-TermideskHaWizardArtifacts -Settings $s
    Write-Host "Готово: $(Get-TermideskOutputPath '18-ha-wizard')" -ForegroundColor Green
}

if ($SkipMenu) {
    if (-not $GenerateHa) {
        Write-Host 'Указан -SkipMenu без -GenerateHa — выход после импорта.' -ForegroundColor DarkGray
    }
    return
}

Start-TermideskMenu -OpenHaWizard:$HaWizard
