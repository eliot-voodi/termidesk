# ИБ-101
$portal = 'https://disp1.termidesk.local'
$key = ''
if (-not $key) { Write-Host 'FAIL: задайте healthCheckAccessKey'; exit 1 }
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$h = Invoke-RestMethod -Uri "$portal/api/health/?key=$key"
Write-Host 'OK ИБ-101:' ($h | ConvertTo-Json -Compress)