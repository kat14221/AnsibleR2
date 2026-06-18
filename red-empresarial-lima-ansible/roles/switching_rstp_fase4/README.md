# Rol: switching_rstp_fase4

## Propósito

Habilita RSTP en el bridge Open vSwitch de cada switch Lima y configura la prioridad por jerarquía para garantizar un árbol spanning-tree determinístico.

## ¿Qué hace este rol?

1. **Precheck**: valida `rstp_enabled`, `rstp_bridge` y `rstp_priority` desde `host_vars`. Verifica que el bridge OVS existe.
2. **Diagnóstico antes**: muestra estado RSTP actual, `other_config` y puertos del bridge.
3. **Aplica**: `rstp_enable=true` + `other_config:rstp-priority=<valor>`.
4. **Pausa**: 10 segundos para convergencia del árbol.
5. **Valida**: confirma con assert que `rstp_enable=true` y muestra `ovs-appctl rstp/show`.

## ¿Qué NO toca este rol?

- Puertos OVS, bonds, trunks, VLAN tags
- IPs, SVIs, VRRP, Keepalived
- Fases 2 ni 3 ya aplicadas
- VMs, ESXi, OPNsense, routers/firewalls

## Variables requeridas en host_vars

```yaml
rstp_enabled: true          # bool — debe ser true explícitamente
rstp_bridge: "br-core"      # nombre del bridge OVS del switch
rstp_priority: 4096         # prioridad RSTP (múltiplo de 4096)
rstp_expected_role: "root-primary"  # solo documentación
```

## Tabla de prioridades Lima

| Switch       | Bridge   | Prioridad | Rol                     |
|---|---|---|---|
| SWCORELIM1   | br-core  | 4096      | Root Bridge principal   |
| SWCORELIM2   | br-core  | 8192      | Root Bridge secundario  |
| SWDISTLIM1   | br-dist  | 16384     | Distribución primaria   |
| SWDISTLIM2   | br-dist  | 20480     | Distribución secundaria |
| SWACCLIM1    | br-acc   | 32768     | Acceso                  |
| SWACCLIM2    | br-acc   | 36864     | Acceso                  |

## Rollback manual

Si RSTP genera problemas, desactivar con:

```bash
sudo ovs-vsctl set bridge <bridge> rstp_enable=false
```

## Equivalentes manuales de los comandos aplicados

```bash
sudo ovs-vsctl set bridge br-core rstp_enable=true
sudo ovs-vsctl set bridge br-core other_config:rstp-priority=4096
ovs-appctl rstp/show br-core
```
