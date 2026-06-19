# Fase 6A: Uplink Trunk hacia Hypervisor H2

Esta fase tiene como objetivo dar visibilidad de red a las VMs alojadas en el **Hypervisor H2 (Servicios)**, permitiéndoles alcanzar el gateway VRRP configurado en los switches Core.

## Justificación
La VM `ADMIN-LIMA` se encuentra en el Port Group `PG-LIMA-ADMIN-VLAN10` en el Hypervisor H2, operando en la VLAN 10. Al carecer de un enlace L2 configurado desde el switch de acceso hacia el vSwitch de H2, el tráfico quedaba aislado y los pings hacia el gateway `192.168.10.1` resultaban en `Destination host unreachable`.

## Detalles de Implementación
Se identificó la interfaz física conectada al Port Group trunk hacia H2 mediante su dirección MAC (`00:0c:29:7b:40:1b`), la cual corresponde a la interfaz Linux `ens41` en `SWACCLIM1`.

El rol de Ansible `access_h2_trunk_fase6a` ejecuta de forma idempotente y controlada la configuración:
1. Levanta la interfaz física `ens41`.
2. Agrega la interfaz al bridge local `br-acc`.
3. Configura el modo de VLAN a `trunk` (`vlan_mode=trunk`).
4. Declara explícitamente las VLANs permitidas (`trunks=10,20,30,40,50,60,70,80,99`).

## Prevención de Bucles L2
Por precaución y diseño seguro, la conectividad hacia H2 se habilita **únicamente en SWACCLIM1**. La variable `fase6a_h2_trunk_enabled` en `SWACCLIM2` se ha declarado explícitamente en `false`. Si en el futuro se desea tener redundancia hacia H2, se requerirá un rediseño que incluya bonding o mecanismos activos de prevención de bucles L2 (STP) sobre estos enlaces, pero por ahora se mantiene como standby (deshabilitado).

## Validación
Tras la aplicación del playbook `10_configurar_h2_trunk_swacclim1_local.yml`, se puede usar el playbook de validación:
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_h2_trunk_swacclim1_local.yml -vv -K
```

Prueba de éxito esperada en la VM `ADMIN-LIMA`:
```cmd
ping 192.168.10.1
ping 192.168.10.125
ping 8.8.8.8
```

## Rollback
Si se requiere deshacer los cambios, ejecutar manualmente:
```bash
sudo ovs-vsctl --if-exists del-port br-acc ens41
sudo ip link set ens41 down
```
