$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Validacion Local Zabbix Agent 2 Windows ==="
hostname
ipconfig /all

$service = Get-Service | Where-Object { $_.Name -like "*Zabbix*" -or $_.DisplayName -like "*Zabbix*" }
if (-not $service) {
    Write-Host "ERROR: No se encontró ningún servicio Zabbix en el sistema."
    exit 1
}
$service

$listener = Get-NetTCPConnection -LocalPort 10050 -ErrorAction SilentlyContinue
if (-not $listener) {
    Write-Host "ERROR: No hay ningún proceso escuchando en el puerto TCP 10050."
    exit 1
}
$listener

Get-NetFirewallRule -DisplayName "JHALEX Zabbix Agent 10050" -ErrorAction SilentlyContinue

$PossibleConfigPaths = @(
  "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf",
  "C:\Program Files\Zabbix Agent 2\conf\zabbix_agent2.conf",
  "C:\Program Files\Zabbix Agent\zabbix_agentd.conf"
)

$ConfigPath = $PossibleConfigPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ConfigPath) {
    Get-Content $ConfigPath | Select-String "Server=|ServerActive=|Hostname=|ListenPort="
} else {
    Write-Host "ERROR: No se encontró config Zabbix."
    exit 1
}

Write-Host "=== Validacion finalizada exitosamente ==="
