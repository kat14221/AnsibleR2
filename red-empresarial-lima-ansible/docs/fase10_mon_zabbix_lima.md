# FASE 10: Servidor de Monitoreo Empresarial (MON-ZABBIX-LIMA)

Este documento detalla la configuración y arquitectura técnica empleada para desplegar el servidor de monitoreo central Zabbix en la sede de Lima.

## 1. Objetivo de MON-ZABBIX-LIMA
Proveer una plataforma centralizada y proactiva de monitoreo de disponibilidad, rendimiento e incidencias (fault & performance management) para los equipos de red, servidores y servicios críticos de la empresa. La adopción de Zabbix 7.0 LTS garantiza la estabilidad a largo plazo y soporte corporativo necesario.

## 2. Por qué se ubica en VLAN 70
La VLAN 70 es el segmento de gestión y monitoreo (`VLAN70-MONITOREO-LIMA`). Aislar el servidor Zabbix en esta VLAN:
- Protege la recolección de métricas frente a saturación y broadcast de usuarios (VLAN 20).
- Aplica seguridad Zero Trust: solo los administradores en VLAN 10 pueden acceder a la interfaz web, y los switches solo permiten consultas SNMP o conexiones del Agente provenientes de la VLAN 70.

## 3. Uso de IP fija 192.168.70.2
Si bien la VLAN 70 posee un scope DHCP (`192.168.70.10` - `192.168.70.25`), un servidor de infraestructura central como Zabbix jamás debe depender del lease de DHCP. Se le asignó rígidamente la IP estática `192.168.70.2` para que los agentes Zabbix instalados en otros hosts (ej. Active Directory) sepan exactamente a qué IP enviar sus métricas (Active Checks) de forma determinista y segura.

## 4. Componentes instalados
El despliegue monolítico inicial incluye:
- **Zabbix Server:** Motor central recolector de métricas.
- **Zabbix Frontend (PHP/Apache):** Interfaz web corporativa de gestión.
- **Zabbix Agent 2:** Agente moderno (escrito en Go) para auto-monitoreo local de la máquina.
- **PostgreSQL 16:** Motor de base de datos relacional elegido sobre MySQL/MariaDB por su excepcional rendimiento histórico en alta concurrencia de inserciones de monitoreo.

## 5. Targets iniciales a monitorear
Se ha dejado el archivo `/etc/zabbix/jhalex_targets_lima.txt` documentando los equipos iniciales del ecosistema:
- `LIM-DC01` (192.168.40.10)
- `DOC-FILE-BACKUP-LIMA` (192.168.80.2)
- `SWCORELIM1` (192.168.99.11)
- `SWCORELIM2` (192.168.99.12)
- `Gateway VLAN70 VRRP` (192.168.70.1)

## 6. Acceso Web y Credenciales
Se puede acceder al panel desde cualquier máquina autorizada (ej. `ADMIN-LIMA`) vía navegador en:
`http://192.168.70.2/zabbix`

**Credenciales Iniciales (Default):**
- **Usuario:** `Admin` (Sensible a mayúsculas)
- **Password:** `zabbix`
> Es crítico cambiar esta contraseña inmediatamente tras el primer inicio de sesión.

## 7. Validaciones
El playbook de validación verifica:
- Servicios systemd (`postgresql`, `zabbix-server`, `zabbix-agent2`, `apache2`) en estado `active` y `enabled`.
- Inserción correcta del schema de PostgreSQL (tabla `users` existente).
- Comprobación de que la interfaz de Zabbix responde peticiones HTTP en el puerto 80.

## 8. Registro DNS en LIM-DC01 (Opcional)
Para acceder mediante `http://mon-zabbix-lima.jhalex.local/zabbix`, ejecutar en el DC:
```powershell
Add-DnsServerResourceRecordA -ZoneName "jhalex.local" -Name "mon-zabbix-lima" -IPv4Address "192.168.70.2"
```

## 9. Trabajo Futuro y Escalamiento
- **Agregado de hosts:** Integrar paulatinamente los targets usando SNMP (v2c/v3) para switches, e instalación del `zabbix-agent2` para Windows Server y Ubuntu.
- **Escalamiento Multi-sede:** Cuando se integre Huancayo, Arequipa y AWS, `MON-ZABBIX-LIMA` actuará como el servidor maestro. En las sedes remotas, en lugar de replicar el Server, se implementarán **Zabbix Proxies**, los cuales recolectarán la data localmente y la enviarán comprimida a la sede Lima por túneles VPN/SD-WAN.
