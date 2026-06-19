# Role: access_h2_trunk_fase6a

Este rol es el encargado de implementar la **FASE 6A**, configurando el enlace físico desde SWACCLIM1 hacia el Hypervisor H2 de la Sede Lima.

## Descripción

El rol identifica la interfaz dedicada hacia H2 (`ens41`), la levanta y la agrega al bridge `br-acc` de Open vSwitch configurándola explícitamente en modo `trunk` con todas las VLANs necesarias permitidas.

Esto es necesario para que las VMs dentro del host ESXi H2, como `ADMIN-LIMA`, tengan visibilidad de red hacia el gateway L3.

## Funciones
- Levantar administrativamente la interfaz (UP).
- Agregar al bridge (`add-port`).
- Configurar VLAN trunking (`vlan_mode=trunk`, `trunks=10,20,30,40...`).
- Validar existencia en el bridge post-configuración.

## Variables Principales
Las variables se encuentran en `host_vars/<host>.yml`:
- `fase6a_h2_trunk_enabled`
- `fase6a_h2_bridge`
- `fase6a_h2_trunk_interface`
- `fase6a_h2_trunk_vlans`
