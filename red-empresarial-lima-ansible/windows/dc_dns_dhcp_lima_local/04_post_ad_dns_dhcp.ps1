. .\00_config_local_variables.ps1

Write-Host "========================================"
Write-Host " POST AD: DNS FORWARDERS Y DHCP         "
Write-Host "========================================"

# Detectar interfaz activa
$Adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Sort-Object ifIndex | Select-Object -First 1

if (-not $Adapter) {
    throw "No se encontró ningún adaptador de red activo."
}

# Configurar DNS final
Write-Host "Configurando DNS final a $($JhalexConfig.DnsFinal)..."
Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ServerAddresses $JhalexConfig.DnsFinal

# Configurar forwarders DNS sin duplicar
Write-Host "Configurando Forwarders DNS..."
$ExistingForwarders = @()
try {
    $ExistingForwarders = (Get-DnsServerForwarder).IPAddress.IPAddressToString
} catch {}

foreach ($Forwarder in $JhalexConfig.DnsForwarders) {
    if ($ExistingForwarders -notcontains $Forwarder) {
        Write-Host "Agregando Forwarder: $Forwarder"
        Add-DnsServerForwarder -IPAddress $Forwarder
    } else {
        Write-Host "Forwarder $Forwarder ya existe."
    }
}

# Autorizar DHCP en AD sin duplicar
Write-Host "Autorizando DHCP Server en Active Directory..."
$DhcpAuthorized = Get-DhcpServerInDC -ErrorAction SilentlyContinue |
    Where-Object {$_.IPAddress -eq $JhalexConfig.IPAddress}

if (-not $DhcpAuthorized) {
    Add-DhcpServerInDC `
        -DnsName "$($JhalexConfig.Hostname).$($JhalexConfig.DomainName)" `
        -IPAddress $JhalexConfig.IPAddress
    Write-Host "DHCP autorizado correctamente."
} else {
    Write-Host "DHCP ya estaba autorizado en AD."
}

# Marcar post-install de DHCP
Write-Host "Marcando post-install de DHCP..."
Set-ItemProperty `
    -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 `
    -Name ConfigurationState `
    -Value 2 `
    -ErrorAction SilentlyContinue

Write-Host "Configuración POST AD completada."
