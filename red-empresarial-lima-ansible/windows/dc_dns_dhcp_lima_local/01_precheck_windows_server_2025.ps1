. .\00_config_local_variables.ps1

Write-Host "========================================"
Write-Host " PRECHECK WINDOWS SERVER 2025 & RED     "
Write-Host "========================================"

Write-Host "`n--- PowerShell Version ---"
$PSVersionTable

Write-Host "`n--- OS Version ---"
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsName, OsVersion

Write-Host "`n--- Network Adapters ---"
Get-NetAdapter

Write-Host "`n--- IP Addresses ---"
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4' -and $_.IPAddress -notlike '127.*'}

Write-Host "`n--- DNS Client Config ---"
Get-DnsClientServerAddress -AddressFamily IPv4

Write-Host "`n--- Connectivity Test (Gateway) ---"
Test-Connection $JhalexConfig.Gateway -Count 4

Write-Host "`n--- Connectivity Test (External 8.8.8.8) ---"
Test-Connection 8.8.8.8 -Count 4

Write-Host "`n--- DNS Resolution Test (google.com) ---"
Resolve-DnsName google.com

Write-Host "`nValidacion completada. Revisa que:"
Write-Host "1. Se detecte Windows Server 2025."
Write-Host "2. Exista al menos un adaptador 'Up'."
Write-Host "3. Se pueda llegar al gateway 192.168.40.1."
Write-Host "4. Se pueda resolver DNS externo."
