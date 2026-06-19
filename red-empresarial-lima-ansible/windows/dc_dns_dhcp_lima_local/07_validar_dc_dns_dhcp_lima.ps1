Write-Host "========================================"
Write-Host " VALIDACION FINAL DC DNS DHCP LIMA      "
Write-Host "========================================"

Write-Host "`n--- OS Info ---"
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsName, OsVersion

Write-Host "`n--- Hostname ---"
hostname

Write-Host "`n--- IP Config ---"
ipconfig /all

Write-Host "`n--- Windows Features ---"
Get-WindowsFeature AD-Domain-Services,DNS,DHCP

Write-Host "`n--- Active Directory ---"
try {
    Get-ADDomain
    Get-ADForest
    Write-Host "`nAD Sites:"
    Get-ADReplicationSite -Filter * | Select-Object Name
    Write-Host "`nAD Subnets:"
    Get-ADReplicationSubnet -Filter * | Select-Object Name, Site
    Write-Host "`nAD OUs:"
    Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
} catch {
    Write-Host "No se pudo consultar AD. ¿Se promovió correctamente?"
}

Write-Host "`n--- DNS ---"
Write-Host "Forwarders:"
Get-DnsServerForwarder
Write-Host "`nResolve externo:"
Resolve-DnsName google.com -ErrorAction SilentlyContinue
Write-Host "`nResolve interno:"
Resolve-DnsName jhalex.local -ErrorAction SilentlyContinue

Write-Host "`n--- DHCP ---"
Write-Host "Authorized DHCP Servers:"
Get-DhcpServerInDC
Write-Host "`nDHCP Scopes:"
Get-DhcpServerv4Scope
Write-Host "`nDHCP Options VLAN 10:"
Get-DhcpServerv4OptionValue -ScopeId 192.168.10.0
Write-Host "`nDHCP Options VLAN 20:"
Get-DhcpServerv4OptionValue -ScopeId 192.168.20.0

Write-Host "`n--- Connectivity ---"
Write-Host "Gateway:"
Test-Connection 192.168.40.1 -Count 4 -ErrorAction SilentlyContinue
Write-Host "Internet (8.8.8.8):"
Test-Connection 8.8.8.8 -Count 4 -ErrorAction SilentlyContinue

Write-Host "`n========================================"
Write-Host " FASE 7 LOCAL DC DNS DHCP LIMA VALIDADA "
Write-Host "========================================"
