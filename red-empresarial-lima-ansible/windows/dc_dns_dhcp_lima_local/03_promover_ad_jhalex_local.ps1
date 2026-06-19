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
    Write-Host "Dominio aún no existe. Continuando promoción..."
}

$SafeModePassword = Read-Host "Ingrese contraseña DSRM para recuperación de AD" -AsSecureString

Write-Host "Iniciando promoción del bosque AD $($JhalexConfig.DomainName)..."
Write-Host "ATENCIÓN: Este proceso reiniciará automáticamente el servidor al finalizar."

Install-ADDSForest `
    -DomainName $JhalexConfig.DomainName `
    -DomainNetbiosName $JhalexConfig.NetbiosName `
    -InstallDns `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Force
