# JHALEX - FASE 7 LOCAL DC DNS DHCP LIMA
# Compatible con Windows PowerShell
# Ejecutar como Administrador desde:
# C:\JHALEX\AnsibleR2\red-empresarial-lima-ansible\windows\dc_dns_dhcp_lima_local

function Test-IsAdmin {
    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Pause-Menu {
    Write-Host ""
    Read-Host "Presione Enter para continuar"
}

function Invoke-JhalexScript {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptName
    )

    $ScriptPath = Join-Path -Path (Get-Location) -ChildPath $ScriptName

    if (-not (Test-Path $ScriptPath)) {
        Write-Host ""
        Write-Host "ERROR: No existe el script: ${ScriptName}" -ForegroundColor Red
        Pause-Menu
        return $false
    }

    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "Ejecutando: ${ScriptName}" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan

    try {
        & $ScriptPath
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -ne $null -and $ExitCode -ne 0) {
            Write-Host ""
            Write-Host "ADVERTENCIA: ${ScriptName} termino con codigo ${ExitCode}" -ForegroundColor Yellow
        } else {
            Write-Host ""
            Write-Host "OK: ${ScriptName} finalizo." -ForegroundColor Green
        }

        Pause-Menu
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "ERROR en ${ScriptName}: $($_.Exception.Message)" -ForegroundColor Red
        Pause-Menu
        return $false
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host " JHALEX - FASE 7 LOCAL DC DNS DHCP LIMA" -ForegroundColor Cyan
    Write-Host " Windows Server 2025 Datacenter Evaluation 24H2" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Precheck Windows Server 2025 y red"
    Write-Host "2. Configurar IP, hostname y roles AD/DNS/DHCP"
    Write-Host "3. Promover Active Directory jhalex.local"
    Write-Host "4. Post AD: DNS forwarders y autorizacion DHCP"
    Write-Host "5. Crear OUs, Sites y Subnets"
    Write-Host "6. Crear scopes DHCP Lima"
    Write-Host "7. Validar todo"
    Write-Host "8. Guia secuencial segura"
    Write-Host "0. Salir"
    Write-Host ""
}

function Run-Sequential {
    Write-Host ""
    Write-Host "GUIA SECUENCIAL SEGURA" -ForegroundColor Yellow
    Write-Host "Se ejecutara precheck y configuracion inicial."
    Write-Host "Si se cambia hostname, reinicie antes de continuar."
    Write-Host ""

    $ok = Invoke-JhalexScript -ScriptName "01_precheck_windows_server_2025.ps1"
    if (-not $ok) { return }

    $ok = Invoke-JhalexScript -ScriptName "02_configurar_red_hostname_roles.ps1"
    if (-not $ok) { return }

    Write-Host ""
    Write-Host "IMPORTANTE:" -ForegroundColor Yellow
    Write-Host "Si el paso 2 cambio el hostname a LIM-DC01, reinicie ahora:"
    Write-Host "Restart-Computer"
    Write-Host ""
    Write-Host "Luego vuelva a abrir PowerShell como Administrador y ejecute el menu desde esta carpeta."
    Pause-Menu
}

if (-not (Test-IsAdmin)) {
    Write-Host ""
    Write-Host "ERROR: Debe ejecutar PowerShell como Administrador." -ForegroundColor Red
    Write-Host "Cierre esta consola, abra PowerShell como Administrador y vuelva a ejecutar:"
    Write-Host ".\Run-Fase7-Menu.ps1"
    Write-Host ""
    exit 1
}

Set-ExecutionPolicy Bypass -Scope Process -Force

do {
    Show-Menu
    $Option = Read-Host "Seleccione una opcion"

    switch ($Option) {
        "1" {
            Invoke-JhalexScript -ScriptName "01_precheck_windows_server_2025.ps1"
        }
        "2" {
            Invoke-JhalexScript -ScriptName "02_configurar_red_hostname_roles.ps1"
            Write-Host ""
            Write-Host "Si se cambio el hostname, reinicie con: Restart-Computer" -ForegroundColor Yellow
            Pause-Menu
        }
        "3" {
            Write-Host ""
            Write-Host "ADVERTENCIA: Este paso promueve el servidor a Domain Controller." -ForegroundColor Yellow
            Write-Host "El servidor se reiniciara automaticamente al finalizar."
            $Confirm = Read-Host "Escriba SI para continuar"
            if ($Confirm -eq "SI") {
                Invoke-JhalexScript -ScriptName "03_promover_ad_jhalex_local.ps1"
            } else {
                Write-Host "Operacion cancelada." -ForegroundColor Yellow
                Pause-Menu
            }
        }
        "4" {
            Invoke-JhalexScript -ScriptName "04_post_ad_dns_dhcp.ps1"
        }
        "5" {
            Invoke-JhalexScript -ScriptName "05_crear_ous_sites_subnets.ps1"
        }
        "6" {
            Invoke-JhalexScript -ScriptName "06_crear_scopes_dhcp_lima.ps1"
        }
        "7" {
            Invoke-JhalexScript -ScriptName "07_validar_dc_dns_dhcp_lima.ps1"
        }
        "8" {
            Run-Sequential
        }
        "0" {
            Write-Host "Saliendo..."
        }
        default {
            Write-Host ""
            Write-Host "Opcion invalida." -ForegroundColor Yellow
            Pause-Menu
        }
    }
}
while ($Option -ne "0")
