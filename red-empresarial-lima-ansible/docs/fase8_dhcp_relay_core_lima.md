# FASE 8: DHCP Relay en Core Lima

Este documento detalla la implementación del servicio DHCP Relay en los switches Core (`SWCORELIM1` y `SWCORELIM2`) de la sede Lima.

## 1. Por qué DHCP Relay es necesario
El protocolo DHCP funciona nativamente mediante la emisión de mensajes de broadcast (como DHCPDISCOVER). Por diseño, los routers e interfaces de Capa 3 no reenvían paquetes de broadcast de una subred a otra. Por lo tanto, si un cliente está en una VLAN diferente a la del servidor DHCP, sus solicitudes nunca llegarán al servidor. El DHCP Relay resuelve esto interceptando los broadcasts y enviándolos como paquetes unicast al servidor DHCP.

## 2. Ubicación del Servidor DHCP
El servidor DHCP (`LIM-DC01`) se encuentra alojado en la **VLAN 40 (Servidores)**, con la IP estática `192.168.40.10`. Los clientes (usuarios, teléfonos, visitantes, administradores) se conectan en diferentes VLANs a lo largo de la sede.

## 3. Comportamiento del Broadcast
Como los Gateways predeterminados de todas las VLANs (las interfaces SVI) residen en los switches Core, es allí donde los mensajes de broadcast de DHCP mueren si no existe un agente Relay configurado para interceptarlos.

## 4. Los Core actúan como Relay L3
Para garantizar alta disponibilidad y tolerancia a fallos, **ambos** switches Core (`SWCORELIM1` y `SWCORELIM2`) están configurados como agentes DHCP Relay utilizando el servicio `isc-dhcp-relay` de Linux. Si un Core cae o el tráfico VRRP migra, el Core activo capturará las peticiones y las enviará al servidor.

## 5. Servidor Destino
Todo el tráfico interceptado se reenvía a `192.168.40.10`. El servidor DHCP de Windows Server se encarga de determinar, en base a la IP de la interfaz que hizo el relay (GIADDR), de qué scope debe extraer la IP para el cliente.

## 6. Interfaces configuradas
El agente DHCP Relay está configurado para escuchar en las siguientes interfaces SVI:
- `svi-vlan10` (Administración)
- `svi-vlan20` (Usuarios)
- `svi-vlan30` (Invitados)
- `svi-vlan60` (Voz IP)
- `svi-vlan70` (Monitoreo)
- `svi-vlan80` (Backup/Storage)
- `svi-vlan99` (Gestión Core)

## 7. Interfaces excluidas
- **VLAN 40 (Servidores)**: El servidor DHCP y los demás servidores de esta VLAN poseen IP fija o están en el mismo dominio de broadcast L2 que el DHCP, por lo que las solicitudes locales no requieren reenvío L3.
- **VLAN 50 (DMZ)**: Por razones estrictas de seguridad de arquitectura perimetral, la DMZ no utiliza direccionamiento IP dinámico, por lo que el DHCP Relay ha sido excluido de esta interfaz.

## 8. Validaciones
El playbook de validación verifica:
- La correcta resolución de las SVIs implicadas.
- La conectividad ICMP (`ping`) hacia el AD/DHCP `192.168.40.10`.
- El estado activo y de inicio automático de `isc-dhcp-relay`.
- Que los procesos del sistema (`ps aux`) registren al daemon `dhcrelay` inyectando opciones sobre las interfaces correctas.

## 9. Prueba final con cliente
Para corroborar todo el flujo DHCP (Cliente -> Access -> Core -> Relay -> DC01 -> Core -> Access -> Cliente), se puede probar con la VM `ADMIN-LIMA` ubicada en H2:
1. Conectar la VM al Port Group `PG-LIMA-ADMIN-VLAN10`.
2. Establecer la interfaz en Windows para obtener IP automáticamente.
3. Ejecutar `ipconfig /release` y luego `ipconfig /renew`.
4. El cliente deberá recibir una IP del segmento `192.168.10.0/25`, Gateway `192.168.10.1`, y DNS `192.168.40.10`.
5. En `LIM-DC01`, el administrador puede verificar el préstamo (lease) desde PowerShell mediante `Get-DhcpServerv4Lease -ScopeId 192.168.10.0`.
