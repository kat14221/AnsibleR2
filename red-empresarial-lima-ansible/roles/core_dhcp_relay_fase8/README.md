# core_dhcp_relay_fase8

Rol para habilitar el reenvío de paquetes DHCP (DHCP Relay) en los switches Core Linux (SWCORELIM1 / SWCORELIM2) utilizando `isc-dhcp-relay`.

## Descripción
Los clientes que se encuentran en VLANs diferentes a la del servidor DHCP no pueden alcanzarlo debido a que los broadcasts DHCP no cruzan los dominios de broadcast (L2). Este rol instala y configura un agente DHCP Relay que escucha solicitudes DHCP en las interfaces SVI locales y las retransmite como unicast hacia el servidor DHCP alojado en la VLAN 40 (LIM-DC01).

## Requisitos
- Debian / Ubuntu con acceso a repositorios para instalar `isc-dhcp-relay`.
- Servidor DHCP (LIM-DC01) accesible vía ping (192.168.40.10).
- Interfaces SVI previamente creadas y en estado UP.

## Variables

| Variable | Descripción | Default |
| -------- | ----------- | ------- |
| `fase8_dhcp_relay_enabled` | Booleano para activar el rol. | `false` |
| `fase8_dhcp_relay_server` | IP del servidor DHCP (LIM-DC01). | `""` |
| `fase8_dhcp_relay_interfaces` | Lista de SVIs donde debe escuchar el relay. | `[]` |
| `fase8_dhcp_relay_excluded_interfaces` | SVIs donde NO debe configurarse relay. | `[]` |

## Tareas principales
1. Verificación de exclusión estricta de VLANs no deseadas (40 y 50).
2. Verificación de existencia de las interfaces destino.
3. Ping de prueba al servidor DHCP.
4. Instalación de `isc-dhcp-relay`.
5. Creación del archivo de configuración `/etc/default/isc-dhcp-relay`.
6. Reinicio del servicio para aplicar los cambios.
