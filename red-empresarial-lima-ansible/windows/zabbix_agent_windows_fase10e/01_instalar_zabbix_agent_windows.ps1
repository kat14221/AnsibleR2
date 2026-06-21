param(
  [Parameter(Mandatory=$true)]
  [string]$ZabbixServer,

  [Parameter(Mandatory=$true)]
  [string]$Hostname,

  [string]$ZabbixVersion = "7.0.21"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Este script debe ejecutarse como Administrador."
}

Write-Host "1. Validando conectividad a Zabbix Server ($ZabbixServer)..."
Test-Connection $ZabbixServer -Count 3 -ErrorAction Stop

Write-Host "2. Creando carpeta temporal..."
New-Item -ItemType Directory -Force -Path "C:\Temp\Zabbix"

Write-Host "3. Limpiando instalaciones parciales anteriores..."
Get-Service "Zabbix Agent 2" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
Get-Service "Zabbix Agent" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue

Write-Host "4. Descargando MSI de Zabbix Agent 2..."
$BaseUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$ZabbixVersion"
$MsiName = "zabbix_agent2-$ZabbixVersion-windows-amd64-openssl.msi"
$MsiUrl  = "$BaseUrl/$MsiName"
$MsiPath = "C:\Temp\Zabbix\$MsiName"

Write-Host "Descargando $MsiUrl"
try {
    Invoke-WebRequest -Uri $MsiUrl -OutFile $MsiPath -UseBasicParsing -ErrorAction Stop
}
catch {
    throw "No se pudo descargar el MSI desde $MsiUrl. Error: $($_.Exception.Message)"
}

if (-not (Test-Path $MsiPath)) {
    throw "No se descargó el MSI: $MsiPath"
}

if ((Get-Item $MsiPath).Length -lt 1MB) {
    throw "El MSI descargado parece inválido o incompleto: $MsiPath"
}

Write-Host "5. Instalando Zabbix Agent 2 con MSI..."
$Arguments = @(
  "/i", "`"$MsiPath`"",
  "/qn",
  "SERVER=$ZabbixServer",
  "SERVERACTIVE=$ZabbixServer",
  "HOSTNAME=$Hostname",
  "LISTENPORT=10050"
)

$process = Start-Process msiexec.exe -ArgumentList $Arguments -Wait -PassThru

if ($process.ExitCode -ne 0) {
    throw "msiexec falló con ExitCode $($process.ExitCode)"
}

Write-Host "6. Buscando servicio real..."
$service = Get-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue

if (-not $service) {
    $service = Get-Service | Where-Object { $_.Name -like "*Zabbix*" -or $_.DisplayName -like "*Zabbix*" } | Select-Object -First 1
}

if (-not $service) {
    throw "No se encontró ningún servicio Zabbix después de instalar el MSI."
}

$ServiceName = $service.Name
Write-Host "Servicio detectado: $ServiceName"

Write-Host "7. Configurando archivo .conf real..."
$PossibleConfigPaths = @(
  "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf",
  "C:\Program Files\Zabbix Agent 2\conf\zabbix_agent2.conf",
  "C:\Program Files\Zabbix Agent\zabbix_agentd.conf"
)

$ConfigPath = $PossibleConfigPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $ConfigPath) {
    throw "No se encontró archivo de configuración del agente Zabbix."
}

@"
Server=$ZabbixServer
ServerActive=$ZabbixServer
Hostname=$Hostname
ListenPort=10050
"@ | Set-Content -Path $ConfigPath -Encoding ASCII

Write-Host "8. Abriendo firewall Windows limpio y sin duplicados..."
Get-NetFirewallRule -DisplayName "JHALEX Zabbix Agent 10050" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

New-NetFirewallRule `
  -DisplayName "JHALEX Zabbix Agent 10050" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 10050 `
  -RemoteAddress $ZabbixServer `
  -Action Allow `
  -Profile Any

Write-Host "9. Iniciando servicio Zabbix Agent 2 real..."
Start-Service -Name $ServiceName
Set-Service -Name $ServiceName -StartupType Automatic

Start-Sleep -Seconds 3

$svc = Get-Service -Name $ServiceName
if ($svc.Status -ne "Running") {
    throw "El servicio $ServiceName no quedó en Running. Estado actual: $($svc.Status)"
}

Write-Host "10. Validando puerto 10050..."
$listener = Get-NetTCPConnection -LocalPort 10050 -ErrorAction SilentlyContinue

if (-not $listener) {
    throw "El puerto TCP 10050 no está escuchando."
}

Write-Host "OK: Zabbix Agent Windows instalado y validado correctamente."
Write-Host "Servicio: $ServiceName"
Write-Host "Config: $ConfigPath"
Write-Host "Server: $ZabbixServer"
Write-Host "Hostname: $Hostname"
