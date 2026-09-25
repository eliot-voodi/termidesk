# ИБ-112
$s = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent) 'config/termidesk-settings.json') -Raw | ConvertFrom-Json
foreach ($d in $s.cluster.dispatchers) { Write-Host "Dispatcher $($d.ip)" }
Write-Host 'Проверьте failover: отключите один узел, VIP доступен'