# FASE 10E - Zabbix Agent Windows Lima

## Objetivo
Instalación y configuración del agente Zabbix 7.0 en equipos Windows de la sede Lima.

## Hosts objetivo
- **LIM-DC01** (192.168.40.10)
- **ADMIN-LIMA** (192.168.10.20)

## Archivos involucrados
- `roles/zabbix_agent_windows_fase10e/*`
- `windows/zabbix_agent_windows_fase10e/01_instalar_zabbix_agent_windows.ps1`
- `windows/zabbix_agent_windows_fase10e/02_validar_zabbix_agent_windows.ps1`
- Playbooks `26_win_instalar...`, `27_win_instalar...`, `99_win_validar...`

## Pasos manuales con PowerShell
Si no se dispone de WinRM activo, ejecutar localmente en cada máquina como Administrador.

### Para ADMIN-LIMA

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

.\01_instalar_zabbix_agent_windows.ps1 `
  -ZabbixServer "192.168.70.2" `
  -Hostname "ADMIN-LIMA"

.\02_validar_zabbix_agent_windows.ps1
```

### Para LIM-DC01

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

.\01_instalar_zabbix_agent_windows.ps1 `
  -ZabbixServer "192.168.70.2" `
  -Hostname "LIM-DC01"

.\02_validar_zabbix_agent_windows.ps1
```

## Validación final
Desde el servidor `MON-ZABBIX-LIMA`:

```bash
nc -vz 192.168.10.20 10050
nc -vz 192.168.40.10 10050

zabbix_get -s 192.168.10.20 -k agent.ping
zabbix_get -s 192.168.40.10 -k agent.ping
```

Debe devolver:
```text
1
```

Añadir en el Frontend de Zabbix la plantilla **Windows by Zabbix agent**.
