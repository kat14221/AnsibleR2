# FASE 7 LOCAL — DC DNS DHCP Lima en Windows Server 2025

## 1. Objetivo de la fase
Desplegar la infraestructura fundacional de Identidad, Resolución de Nombres y Asignación de IP Dinámica para la sede principal en Lima, sentando las bases del dominio unificado y la arquitectura multi-sede.

## 2. Por qué la ejecución será local y no por WinRM
El bootstrapping de un dominio nuevo a partir de una VM en grupo de trabajo a menudo rompe las conexiones remotas (WinRM) cuando el servidor se reinicia o cambia de estado, además de posibles problemas de credenciales remotas al convertirse en Domain Controller. La ejecución local de scripts asegura cero pérdida de conectividad durante el aprovisionamiento crítico.

## 3. Por qué no se usará Ansible remoto
Para evitar la complejidad de gestionar WinRM (con sus requerimientos de HTTPS, certificados o AllowUnencrypted), credenciales locales vs. de dominio en el inventario, y la reconexión durante reinicios obligatorios (renombrado de host y promoción de AD). Al usar scripts locales clonados vía Git, simplificamos radicalmente el despliegue fundacional.

## 4. Por qué se segmenta por reinicios
Operaciones fundamentales en Windows Server como el cambio de Hostname y la promoción de un bosque Active Directory exigen un reinicio limpio del sistema operativo para aplicar los cambios a nivel de kernel y registro. Segmentar los scripts permite pausar de forma segura, reiniciar, y reanudar la fase siguiente sin errores de estado.

## 5. VM visible
En ESXi, la máquina virtual es aprovisionada como `DC-DNS-DHCP-LIMA`.

## 6. Hostname real
Internamente, el SO tomará el nombre de `LIM-DC01` conforme a la nomenclatura corporativa.

## 7. Dominio único
Se implementará un único bosque y dominio `jhalex.local`. No se crearán dominios secundarios ni subdominios por sede (evitando `lima.local` o similares) para simplificar la administración.

## 8. Sites AD
Se declaran tres sitios de replicación Active Directory anticipando la expansión:
- `SITE-LIM-ESXI` (Sede Lima, Virtualizado)
- `SITE-HYO-FISICA` (Sede Huancayo, Físico)
- `SITE-AQP-AWS` (Sede Arequipa, Nube)

## 9. OUs base por sede
Para organización, se creará un bloque raíz `OU=JHALEX` y debajo OUs para `LIMA`, `HUANCAYO` y `AREQUIPA`, con sus respectivas sub-OUs (`Usuarios`, `Equipos`, `Servidores`, `Grupos`).

## 10. DHCP solo para Lima
Se implementan únicamente los scopes correspondientes a las redes LAN/VLAN locales de Lima, ya que el servicio DHCP no rutea IPs a sedes remotas que tendrán sus propios servidores DHCP.

## 11. DHCP Relay en Core queda pendiente
Este despliegue establece el servidor DHCP. La configuración en los switches Core para redirigir los broadcasts DHCP (`ip helper-address` o DHCP Relay) se realizará en una fase posterior.

## 12. HYO-DC01
Queda documentado como futuro DC secundario / DNS / DHCP en la sede Huancayo para alta disponibilidad y failover local.

## 13. AQP-DC01 (AWS)
Queda documentado como futuro DC opcional para resolución de DNS local en la nube y Disaster Recovery (DR).

## 14. DMZ VLAN 50 aloja WEB-DMZ-LIMA como respaldo del WEB-AWS
La DMZ (VLAN 50) se diseña para alojar el servidor web local de contingencia (`WEB-DMZ-LIMA`), el cual actuará en caso de caída del servidor web principal alojado en AWS (`WEB-AWS`).

## 15. VLAN 80 se usa para backup/documentos
La red 192.168.80.0/27 está reservada estrictamente para almacenamiento, repositorios de documentos y tareas de backup, separándola completamente de la DMZ u otras cargas de trabajo.
