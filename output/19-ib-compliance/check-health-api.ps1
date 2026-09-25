# ИБ-101: интерфейс состояния объектов аудита ИБ (health/metrics API)
$portal = 'https://disp1.termidesk.local'
$key = ''
if (-not $key) { Write-Host 'Задайте monitoring.healthCheckAccessKey в JSON'; exit 1 }
Enable-TermideskTlsBypass
try {
  $h = Invoke-RestMethod -Uri "$portal/api/health/?key=$key" -Method Get
  Write-Host 'Health API:' ($h | ConvertTo-Json -Compress)
  $m = Invoke-RestMethod -Uri "$portal/api/health/metrics/?key=$key" -Method Get -ErrorAction SilentlyContinue
  if ($m) { Write-Host 'Metrics API OK' }
} catch { Write-Host "FAIL: $_"; exit 1 }