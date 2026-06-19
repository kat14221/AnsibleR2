. .\00_config_local_variables.ps1

Write-Host "========================================"
Write-Host " PROMOVER ACTIVE DIRECTORY              "
Write-Host "========================================"

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $Domain = Get-ADDomain -ErrorAction Stop
    Write-Host "Dominio ya existe: $($Domain.DNSRoot)"
    exit 0
} catch {
    Write-Host "Dominio aun no existe. Continuando promocion..."
}

$SafeModePassword = Read-Host "Ingrese contrasena DSRM para recuperacion de AD" -AsSecureString

Write-Host "Iniciando promocion del bosque AD $($JhalexConfig.DomainName)..."
Write-Host "ATENCION: Este proceso reiniciara automaticamente el servidor al finalizar."

Install-ADDSForest `
    -DomainName $JhalexConfig.DomainName `
    -DomainNetbiosName $JhalexConfig.NetbiosName `
    -InstallDns `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Force
