# FASE 7 LOCAL — DC DNS DHCP Lima Windows Server 2025

Esta fase despliega el primer Domain Controller, servidor DNS y servidor DHCP de la sede Lima. La ejecución es 100% local en la VM de Windows Server mediante scripts PowerShell.

## Qué instalar en la VM
- Windows Server 2025 Datacenter Evaluation 24H2
- Desktop Experience recomendado
- VMware Tools
- Git for Windows

**No instalar Ansible en Windows.**

## Configuración previa de red en ESXi
La VM debe estar conectada a:
- Port Group: `PG-LIMA-SERVIDORES-VLAN40`
- VLAN ID: `40`

## Configuración IP temporal si hace falta
- IP: `192.168.40.10`
- Máscara: `255.255.255.224`
- Gateway: `192.168.40.1`
- DNS: `8.8.8.8`

## Cómo clonar el repo
En PowerShell como Administrador:
```powershell
mkdir C:\JHALEX
cd C:\JHALEX
git clone https://github.com/kat14221/AnsibleR2.git
cd C:\JHALEX\AnsibleR2\red-empresarial-lima-ansible\windows\dc_dns_dhcp_lima_local
```

## Cómo ejecutar

Puedes ejecutar el menú interactivo:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Run-Fase7-Menu.ps1
```

O puedes ejecutar por fases individualmente:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

.\01_precheck_windows_server_2025.ps1
.\02_configurar_red_hostname_roles.ps1

# Si cambió hostname, reiniciar:
Restart-Computer

# Luego volver a abrir PowerShell como Administrador:
cd C:\JHALEX\AnsibleR2\red-empresarial-lima-ansible\windows\dc_dns_dhcp_lima_local
Set-ExecutionPolicy Bypass -Scope Process -Force
.\03_promover_ad_jhalex_local.ps1

# El servidor reiniciará automáticamente por promoción AD.
# Luego continuar:
cd C:\JHALEX\AnsibleR2\red-empresarial-lima-ansible\windows\dc_dns_dhcp_lima_local
Set-ExecutionPolicy Bypass -Scope Process -Force
.\04_post_ad_dns_dhcp.ps1
.\05_crear_ous_sites_subnets.ps1
.\06_crear_scopes_dhcp_lima.ps1
.\07_validar_dc_dns_dhcp_lima.ps1
```
