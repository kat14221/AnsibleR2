# Requires -RunAsAdministrator

function Show-Menu {
    Clear-Host
    Write-Host "====================================================="
    Write-Host " JHALEX - FASE 7 LOCAL DC DNS DHCP LIMA              "
    Write-Host " Windows Server 2025 Datacenter Evaluation 24H2      "
    Write-Host "====================================================="
    Write-Host ""
    Write-Host "1. Precheck Windows Server 2025 y red"
    Write-Host "2. Configurar IP, hostname y roles AD/DNS/DHCP"
    Write-Host "3. Promover Active Directory jhalex.local"
    Write-Host "4. Post AD: DNS forwarders y autorización DHCP"
    Write-Host "5. Crear OUs, Sites y Subnets"
    Write-Host "6. Crear scopes DHCP Lima"
    Write-Host "7. Validar todo"
    Write-Host "8. Ejecutar guía secuencial hasta donde sea seguro"
    Write-Host "0. Salir"
    Write-Host ""
}

function Run-Script {
    param([string]$ScriptName)
    if (Test-Path ".\$ScriptName") {
        Write-Host "`n---> Ejecutando $ScriptName <---" -ForegroundColor Cyan
        try {
            . ".\$ScriptName"
            Write-Host "`n---> $ScriptName finalizado <---" -ForegroundColor Green
        } catch {
            Write-Host "`n---> Error en $ScriptName: $_ <---" -ForegroundColor Red
        }
    } else {
        Write-Host "`n---> Archivo $ScriptName no encontrado <---" -ForegroundColor Red
    }
    Write-Host "`nPresione Enter para continuar..."
    Read-Host
}

function Run-Sequential {
    Write-Host "`n---> Ejecución Secuencial Segura <---" -ForegroundColor Cyan
    
    . ".\01_precheck_windows_server_2025.ps1"
    
    Write-Host "`n¿Desea continuar con Paso 2 (Configurar Red, Hostname, Roles)? (S/N)"
    if ((Read-Host) -notmatch "^[Ss]$") { return }
    
    $Output2 = . ".\02_configurar_red_hostname_roles.ps1" 2>&1
    $Output2 | Write-Host
    if ($Output2 -match "REINICIO_REQUERIDO_HOSTNAME") {
        Write-Host "`n[!] ATENCIÓN: El hostname fue cambiado. Debe reiniciar el servidor antes de promover AD." -ForegroundColor Yellow
        Write-Host "Deteniendo ejecución secuencial. Ejecute Restart-Computer." -ForegroundColor Yellow
        Write-Host "Presione Enter para continuar..."
        Read-Host
        return
    }

    Write-Host "`n¿Desea continuar con Paso 3 (Promover AD)? Esto REINICIARÁ el servidor. (S/N)"
    if ((Read-Host) -notmatch "^[Ss]$") { return }
    
    . ".\03_promover_ad_jhalex_local.ps1"
    
    Write-Host "`nSi el servidor no se reinició automáticamente, debe hacerlo ahora."
    Write-Host "Después del reinicio, abra este menú y use la opción 8 nuevamente (o las opciones 4, 5, 6, 7 manualmente)."
    Write-Host "Presione Enter para continuar..."
    Read-Host
}

# Principal
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Este script debe ejecutarse como Administrador." -ForegroundColor Red
    exit
}

do {
    Show-Menu
    $opcion = Read-Host "Seleccione una opción"
    
    switch ($opcion) {
        '1' { Run-Script "01_precheck_windows_server_2025.ps1" }
        '2' { 
            Write-Host "ADVERTENCIA: Este paso puede requerir reinicio si cambia el hostname." -ForegroundColor Yellow
            Run-Script "02_configurar_red_hostname_roles.ps1" 
        }
        '3' { 
            Write-Host "ADVERTENCIA: Este paso reiniciará automáticamente el servidor." -ForegroundColor Yellow
            Run-Script "03_promover_ad_jhalex_local.ps1" 
        }
        '4' { Run-Script "04_post_ad_dns_dhcp.ps1" }
        '5' { Run-Script "05_crear_ous_sites_subnets.ps1" }
        '6' { Run-Script "06_crear_scopes_dhcp_lima.ps1" }
        '7' { Run-Script "07_validar_dc_dns_dhcp_lima.ps1" }
        '8' { Run-Sequential }
        '0' { Write-Host "Saliendo..."; break }
        default { Write-Host "Opción inválida. Presione Enter..."; Read-Host }
    }
} while ($opcion -ne '0')
