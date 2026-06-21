param(
  [Parameter(Mandatory=$true)]
  [string]$ZabbixServer,

  [Parameter(Mandatory=$true)]
  [string]$Hostname
)

Write-Host "1. Validando conectividad a Zabbix Server ($ZabbixServer)..."
Test-Connection $ZabbixServer -Count 3

Write-Host "2. Creando carpeta temporal..."
New-Item -ItemType Directory -Force -Path "C:\Temp\Zabbix"

Write-Host "3. Descargando MSI de Zabbix Agent 2..."
$MsiUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/7.0.0/zabbix_agent2-7.0.0-windows-amd64-openssl.msi"
$MsiPath = "C:\Temp\Zabbix\zabbix_agent2.msi"
Invoke-WebRequest -Uri $MsiUrl -OutFile $MsiPath

Write-Host "4. Deteniendo servicios previos..."
Get-Service "Zabbix Agent 2" -ErrorAction SilentlyContinue | Stop-Service -Force
Get-Service "Zabbix Agent" -ErrorAction SilentlyContinue | Stop-Service -Force

Write-Host "5. Instalando Zabbix Agent 2 con MSI..."
$installArgs = "/i `"$MsiPath`" /qn SERVER=`"$ZabbixServer`" SERVERACTIVE=`"$ZabbixServer`" HOSTNAME=`"$Hostname`" LISTENPORT=10050 ENABLEPATH=1"
Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow

Write-Host "6. Configurando archivo del agente..."
$confPath = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf"
if (Test-Path $confPath) {
    $confContent = @"
Server=$ZabbixServer
ServerActive=$ZabbixServer
Hostname=$Hostname
ListenPort=10050
"@
    Set-Content -Path $confPath -Value $confContent -Force
}

Write-Host "7. Abriendo firewall Windows..."
New-NetFirewallRule `
  -DisplayName "JHALEX Zabbix Agent 10050" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 10050 `
  -RemoteAddress $ZabbixServer `
  -Action Allow `
  -Profile Any `
  -ErrorAction SilentlyContinue

Write-Host "8. Iniciando servicio Zabbix Agent 2..."
Start-Service "Zabbix Agent 2"
Set-Service "Zabbix Agent 2" -StartupType Automatic

Write-Host "9. Validando servicio y puerto..."
Get-Service "Zabbix Agent 2"
Get-NetTCPConnection -LocalPort 10050 -ErrorAction SilentlyContinue

Write-Host "Instalacion completada."
