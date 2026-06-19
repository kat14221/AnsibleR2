. .\00_config_local_variables.ps1

Write-Host "========================================"
Write-Host " CREAR OUs, SITES Y SUBNETS             "
Write-Host "========================================"

# Función auxiliar para OUs idempotentes
function Ensure-OU {
    param(
        [string]$Name,
        [string]$Path
    )
    $FullDistinguishedName = "OU=$Name,$Path"
    $ExistingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue
    
    if (-not $ExistingOU) {
        Write-Host "Creando OU: $FullDistinguishedName"
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
    } else {
        Write-Host "OU ya existe: $FullDistinguishedName"
    }
}

$DomainDN = (Get-ADDomain).DistinguishedName

# Estructura Base
Ensure-OU -Name "JHALEX" -Path $DomainDN

$BaseOU = "OU=JHALEX,$DomainDN"

# Sedes
$Sedes = @("LIMA", "HUANCAYO", "AREQUIPA")
$SubOUsLima = @("Usuarios", "Equipos", "Servidores", "Grupos", "Administracion")
$SubOUsResto = @("Usuarios", "Equipos", "Servidores", "Grupos")

foreach ($Sede in $Sedes) {
    Ensure-OU -Name $Sede -Path $BaseOU
    $SedePath = "OU=$Sede,$BaseOU"
    
    $SubOUs = if ($Sede -eq "LIMA") { $SubOUsLima } else { $SubOUsResto }
    
    foreach ($SubOU in $SubOUs) {
        Ensure-OU -Name $SubOU -Path $SedePath
    }
}

Write-Host "`n--- AD Sites ---"

$Sites = @($JhalexConfig.SiteLima, $JhalexConfig.SiteHuancayo, $JhalexConfig.SiteArequipa)

foreach ($Site in $Sites) {
    $ExistingSite = Get-ADReplicationSite -Filter "Name -eq '$Site'" -ErrorAction SilentlyContinue
    if (-not $ExistingSite) {
        Write-Host "Creando AD Site: $Site"
        New-ADReplicationSite -Name $Site
    } else {
        Write-Host "AD Site ya existe: $Site"
    }
}

Write-Host "`n--- AD Subnets (Solo Lima por ahora) ---"

foreach ($Subnet in $JhalexConfig.LimaSubnets) {
    $ExistingSubnet = Get-ADReplicationSubnet -Filter "Name -eq '$Subnet'" -ErrorAction SilentlyContinue
    if (-not $ExistingSubnet) {
        Write-Host "Asociando subred $Subnet al site $($JhalexConfig.SiteLima)"
        New-ADReplicationSubnet -Name $Subnet -Site $JhalexConfig.SiteLima
    } else {
        Write-Host "Subred $Subnet ya existe."
    }
}

Write-Host "Creación de OUs, Sites y Subnets completada."
