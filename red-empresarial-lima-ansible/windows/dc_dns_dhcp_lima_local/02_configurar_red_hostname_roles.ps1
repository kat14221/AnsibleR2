. .\00_config_local_variables.ps1

Write-Host "========================================"
Write-Host " CONFIGURAR RED, HOSTNAME Y ROLES       "
Write-Host "========================================"

# Detectar interfaz activa
$Adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Sort-Object ifIndex | Select-Object -First 1

if (-not $Adapter) {
    throw "No se encontró ningún adaptador de red activo."
}

$InterfaceAlias = $Adapter.Name
Write-Host "Usando adaptador: $InterfaceAlias"

# Configurar IP estática
$ExistingIp = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {$_.IPAddress -eq $JhalexConfig.IPAddress}

if (-not $ExistingIp) {
    Write-Host "Configurando IP $($JhalexConfig.IPAddress)..."
    Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {$_.IPAddress -notlike "169.254*"} |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress `
        -InterfaceAlias $InterfaceAlias `
        -IPAddress $JhalexConfig.IPAddress `
        -PrefixLength $JhalexConfig.PrefixLength `
        -DefaultGateway $JhalexConfig.Gateway
} else {
    Write-Host "IP $($JhalexConfig.IPAddress) ya configurada."
}

# Configurar DNS inicial
Write-Host "Configurando DNS inicial..."
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $JhalexConfig.DnsInitial

# Cambiar hostname
if ($env:COMPUTERNAME -ne $JhalexConfig.Hostname) {
    Write-Host "Cambiando hostname a $($JhalexConfig.Hostname)..."
    Rename-Computer -NewName $JhalexConfig.Hostname -Force
    Write-Host "REINICIO_REQUERIDO_HOSTNAME"
} else {
    Write-Host "Hostname ya es $($JhalexConfig.Hostname)."
}

# Instalar roles
Write-Host "Instalando roles AD, DNS, DHCP..."
Install-WindowsFeature AD-Domain-Services,DNS,DHCP -IncludeManagementTools

Write-Host "`n--- Estado de Roles Instalados ---"
Get-WindowsFeature AD-Domain-Services,DNS,DHCP

Write-Host "`nSi el script indicó REINICIO_REQUERIDO_HOSTNAME, debe reiniciar ANTES de promover el AD."
