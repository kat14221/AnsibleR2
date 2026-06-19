. .\00_config_local_variables.ps1

Write-Host "========================================"
Write-Host " CREAR SCOPES DHCP LIMA                 "
Write-Host "========================================"

function Ensure-DhcpScope {
    param(
        [string]$Name,
        [string]$ScopeId,
        [string]$StartRange,
        [string]$EndRange,
        [string]$SubnetMask,
        [string]$Router,
        [string]$DnsServer,
        [string]$DnsDomain
    )

    $Existing = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction SilentlyContinue

    if (-not $Existing) {
        Write-Host "Creando scope: $Name ($ScopeId)..."
        Add-DhcpServerv4Scope `
            -Name $Name `
            -StartRange $StartRange `
            -EndRange $EndRange `
            -SubnetMask $SubnetMask `
            -State Active
    } else {
        Write-Host "Scope ya existe: $Name ($ScopeId)."
    }

    Write-Host "  Asegurando opciones (Router, DNS, Domain) para $ScopeId..."
    Set-DhcpServerv4OptionValue `
        -ScopeId $ScopeId `
        -Router $Router `
        -DnsServer $DnsServer `
        -DnsDomain $DnsDomain
}

Ensure-DhcpScope `
    -Name "VLAN10-ADMIN-LIMA" `
    -ScopeId "192.168.10.0" `
    -StartRange "192.168.10.20" `
    -EndRange "192.168.10.100" `
    -SubnetMask "255.255.255.128" `
    -Router "192.168.10.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Ensure-DhcpScope `
    -Name "VLAN20-USUARIOS-LIMA" `
    -ScopeId "192.168.20.0" `
    -StartRange "192.168.20.20" `
    -EndRange "192.168.20.200" `
    -SubnetMask "255.255.255.0" `
    -Router "192.168.20.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Ensure-DhcpScope `
    -Name "VLAN30-GUEST-LIMA" `
    -ScopeId "192.168.30.0" `
    -StartRange "192.168.30.20" `
    -EndRange "192.168.30.200" `
    -SubnetMask "255.255.255.0" `
    -Router "192.168.30.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Ensure-DhcpScope `
    -Name "VLAN60-VOZ-LIMA" `
    -ScopeId "192.168.60.0" `
    -StartRange "192.168.60.20" `
    -EndRange "192.168.60.100" `
    -SubnetMask "255.255.255.128" `
    -Router "192.168.60.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Ensure-DhcpScope `
    -Name "VLAN70-MONITOREO-LIMA" `
    -ScopeId "192.168.70.0" `
    -StartRange "192.168.70.10" `
    -EndRange "192.168.70.25" `
    -SubnetMask "255.255.255.224" `
    -Router "192.168.70.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Ensure-DhcpScope `
    -Name "VLAN80-BACKUP-LIMA" `
    -ScopeId "192.168.80.0" `
    -StartRange "192.168.80.10" `
    -EndRange "192.168.80.25" `
    -SubnetMask "255.255.255.224" `
    -Router "192.168.80.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Ensure-DhcpScope `
    -Name "VLAN99-GESTION-LIMA" `
    -ScopeId "192.168.99.0" `
    -StartRange "192.168.99.15" `
    -EndRange "192.168.99.25" `
    -SubnetMask "255.255.255.224" `
    -Router "192.168.99.1" `
    -DnsServer "192.168.40.10" `
    -DnsDomain "jhalex.local"

Write-Host "`nCreación de Scopes DHCP completada."
