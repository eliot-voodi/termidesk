# Health Check — Termidesk 7.0
$s = Get-Content 'D:\GPN\scripts\termidesk\config\termidesk-settings.json' -Raw | ConvertFrom-Json
$portal = $s.portal.url
$key = $s.monitoring.healthCheckAccessKey
Enable-TermideskTlsBypass
try {
    $r = Invoke-RestMethod -Uri "$portal/api/health/?key=$key" -Method Get
    Write-Host 'Health OK:' ($r | ConvertTo-Json -Compress) -ForegroundColor Green
} catch { Write-Host "Health FAIL: $_" -ForegroundColor Red }

# Celery nodes
foreach ($n in $s.cluster.celeryManagers) {
    Write-Host "Celery $($n.ip):8103 / 8104"
}