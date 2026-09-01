param()
function Test-Node { param([string]$Ip,[string]$Label)
  Write-Host -NoNewline "  $Label ($Ip): "
  if (Test-Connection $Ip -Count 1 -Quiet -EA SilentlyContinue) { Write-Host OK -ForegroundColor Green } else { Write-Host FAIL -ForegroundColor Red }
}
Write-Host '=== HA Cluster Health Check ===' -ForegroundColor Cyan
Test-Node '192.0.2.30' 'Dispatcher-01 dispatcher'
Test-Node '192.0.2.31' 'Dispatcher-02 dispatcher'
Test-Node '192.0.2.40' 'CeleryMan-01 celery'
Test-Node '192.0.2.41' 'CeleryMan-02 celery'
Test-Node '192.0.2.50' 'Gateway-01 gateway'
Test-Node '192.0.2.51' 'Gateway-02 gateway'
Test-Node '192.0.2.60' 'LB-01 lb'
Test-Node '192.0.2.10' 'PostgreSQL'
Test-Node '192.0.2.10' 'RabbitMQ'
Write-Host "VIP: https://portal.termidesk.local"