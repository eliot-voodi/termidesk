# Создание домена через REST API Termidesk
param([string]$PortalUrl, [string]$User, [string]$Password)
Import-Module "$PSScriptRoot\..\..\modules\Termidesk.Common.psm1" -Force
$conn = Connect-TermideskPortal -Url $PortalUrl -User $User -Password $Password
# Домен: Active Directory
$body = @'
{
    "name":  "Active Directory",
    "type":  "ActiveDirectory",
    "host":  "dc.termidesk.local",
    "port":  389,
    "baseDn":  "DC=termidesk,DC=local",
    "bindUser":  "CN=termidesk-svc,OU=Service,DC=termidesk,DC=local",
    "bindPassword":  "",
    "useSsl":  false
}
'@ | ConvertFrom-Json
# POST /api/authenticators/ или через портал: Аутентификация -> Домены -> Добавить
Write-Host "Добавьте домен 'Active Directory' (ActiveDirectory) через портал или API"