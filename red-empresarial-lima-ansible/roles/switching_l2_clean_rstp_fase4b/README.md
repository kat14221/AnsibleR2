# Rol: switching_l2_clean_rstp_fase4b

## Propósito

**FASE 4B — Limpieza y reaplicación de RSTP funcional en Open vSwitch.**

Este rol corrige el problema identificado en FASE 4: RSTP fue habilitado a nivel de bridge (`rstp_enable=true`) pero los puertos/bonds inter-switch nunca recibieron la configuración `rstp-port-admin-edge=false`. Sin eso, OVS no intercambia BPDUs y cada bridge se proclama Root, generando loops L2, paquetes duplicados (`DUP!`) y pérdida sostenida de paquetes.

## Causa raíz que resuelve

```
rstp/show <bridge>  →  tabla de interfaces vacía
rstp_status: {}     →  el puerto no participa en RSTP
```

**OVS requiere configuración explícita de cada puerto inter-switch:**
```bash
ovs-vsctl set port <bond> other_config:rstp-port-admin-edge=false
ovs-vsctl set port <bond> other_config:rstp-port-auto-edge=false
```

## Flujo del rol

```
1. PRECHECK      — Validar l2_clean_rstp_enabled, variables, bridge y puertos
2. DIAG-ANTES    — Capturar estado completo antes de tocar nada
3. LIMPIEZA      — Limpiar solo config STP/RSTP (no toca bonds, VLANs, IPs)
4. APLICAR       — Habilitar RSTP + prioridad + configurar puertos inter-switch
5. RESTART       — systemctl restart openvswitch-switch + pausa 15s
6. VALIDAR       — Asserts + advertencia si rstp/show sigue vacío
```

## Variables requeridas en host_vars

```yaml
# Guardia del rol — DEBE ser true para ejecutar
l2_clean_rstp_enabled: true

# Bridge OVS objetivo
rstp_bridge: "br-core"          # br-core / br-dist / br-acc según el switch

# Prioridad RSTP (múltiplo de 4096)
rstp_priority: 4096

# Rol esperado (documentación/diagnóstico)
rstp_expected_role: "root-primary"

# Bonds/puertos inter-switch que participan en RSTP — OBLIGATORIO, no vacío
rstp_inter_switch_ports:
  - bond-pcsc1-sc2
  - bond-pcsc1-sd1

# Path costs por puerto (mapa nombre → costo)
rstp_path_costs:
  bond-pcsc1-sc2: 100
  bond-pcsc1-sd1: 100

# Puertos edge (accesos a hosts finales) — puede estar vacío
rstp_edge_ports: []
```

## Tabla de prioridades Lima (FASE 4B)

| Switch       | Bridge   | Prioridad | Rol RSTP                    |
|---|---|---|---|
| SWCORELIM1   | br-core  | 4096      | Root Bridge principal       |
| SWCORELIM2   | br-core  | 8192      | Root Bridge secundario      |
| SWDISTLIM1   | br-dist  | 16384     | Distribución primaria       |
| SWDISTLIM2   | br-dist  | 20480     | Distribución secundaria     |
| SWACCLIM1    | br-acc   | 32768     | Acceso (nunca root)         |
| SWACCLIM2    | br-acc   | 36864     | Acceso (nunca root)         |

## Qué NO toca este rol

- `tag`, `trunks`, `vlan_mode` en puertos OVS
- `interfaces` (miembros físicos del bond)
- `bond_mode`, `bond-primary`
- IPs de bridge, SVIs, rutas estáticas
- Keepalived / VRRP
- OPNsense / RLIM1 / RLIM2
- Archivos Netplan

## Comparación con rol anterior (switching_rstp_fase4)

| Capacidad | switching_rstp_fase4 | switching_l2_clean_rstp_fase4b |
|---|---|---|
| Habilita rstp_enable | ✅ | ✅ |
| Configura prioridad bridge | ✅ | ✅ |
| Configura puertos inter-switch | ❌ | ✅ |
| Limpieza previa | ❌ | ✅ |
| Restart OVS controlado | ❌ | ✅ |
| Validación con asserts | Básica | Completa |
| Detecta tabla rstp/show vacía | ❌ | ✅ (advertencia) |

## Comandos manuales equivalentes (SWCORELIM1 como ejemplo)

```bash
# Limpieza
sudo ovs-vsctl set bridge br-core stp_enable=false
sudo ovs-vsctl set bridge br-core rstp_enable=false
sudo ovs-vsctl clear bridge br-core other_config
sudo ovs-vsctl clear port bond-pcsc1-sc2 rstp_status
sudo ovs-vsctl clear port bond-pcsc1-sc2 rstp_statistics
sudo ovs-vsctl remove port bond-pcsc1-sc2 other_config rstp-port-admin-edge
sudo ovs-vsctl remove port bond-pcsc1-sc2 other_config rstp-port-auto-edge
sudo ovs-vsctl remove port bond-pcsc1-sc2 other_config rstp-port-path-cost

# Reaplicar
sudo ovs-vsctl set bridge br-core rstp_enable=true
sudo ovs-vsctl set bridge br-core other_config:rstp-priority=4096
sudo ovs-vsctl set port bond-pcsc1-sc2 other_config:rstp-port-admin-edge=false
sudo ovs-vsctl set port bond-pcsc1-sc2 other_config:rstp-port-auto-edge=false
sudo ovs-vsctl set port bond-pcsc1-sc2 other_config:rstp-port-path-cost=100
sudo ovs-vsctl set port bond-pcsc1-sd1 other_config:rstp-port-admin-edge=false
sudo ovs-vsctl set port bond-pcsc1-sd1 other_config:rstp-port-auto-edge=false
sudo ovs-vsctl set port bond-pcsc1-sd1 other_config:rstp-port-path-cost=100

# Reinicio y validación
sudo systemctl restart openvswitch-switch
sleep 15
sudo ovs-appctl rstp/show br-core
sudo ovs-ofctl show br-core
```

## Rollback de emergencia

Si RSTP genera problemas, desactivar inmediatamente:

```bash
sudo ovs-vsctl set bridge <bridge> rstp_enable=false
sudo ovs-vsctl set bridge <bridge> stp_enable=false
```

## Criterios para avanzar a FASE 5 (VRRP balanceado)

```
1. ovs-appctl rstp/show <bridge> muestra puertos en tabla
2. SWCORELIM1 aparece como "This bridge is the root" con priority=4096
3. SWCORELIM2 NO aparece como root cuando el enlace Core-Core está activo
4. No hay DUP! en ping entre IPs reales de SVIs
5. No hay packet loss sostenido en pruebas de 30+ paquetes
6. keepalived sigue detenido durante la prueba L2
```
