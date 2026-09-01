# Termidesk 7.0 — проверка готовности кластера
param()

function Test-Node {
    param([string]$Ip, [string]$Label)
    Write-Host -NoNewline "  $Label ($Ip): "
    if (Test-Connection -ComputerName $Ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Host 'OK' -ForegroundColor Green
    } else {
        Write-Host 'FAIL' -ForegroundColor Red
    }
}

Write-Host '=== Проверка сетевой доступности узлов ===' -ForegroundColor Cyan
Test-Node '192.0.2.30' 'Dispatcher-01 (dispatcher)'
Test-Node '192.0.2.31' 'Dispatcher-02 (dispatcher)'
Test-Node '192.0.2.40' 'CeleryMan-01 (celery)'
Test-Node '192.0.2.41' 'CeleryMan-02 (celery)'
Test-Node '192.0.2.50' 'Gateway-01 (gateway)'
Test-Node '192.0.2.51' 'Gateway-02 (gateway)'
Test-Node '192.0.2.10' 'PostgreSQL'
Test-Node '192.0.2.10' 'RabbitMQ'

Write-Host ''
Write-Host '=== Сервисы ===' -ForegroundColor Cyan
Write-Host "  PostgreSQL : 192.0.2.10:5432"
Write-Host "  RabbitMQ   : 192.0.2.10:5672"
Write-Host "  Портал VIP : https://portal.termidesk.local"
Write-Host ''
Write-Host 'На Linux-узлах выполните:' -ForegroundColor Gray
Write-Host '  systemctl status termidesk-vdi termidesk-celery-beat termidesk-celery-worker'