# Rol: switching_l2_nobond_rstp_fase4c

## Propósito

**FASE 4C — Migración de bonds inter-switch a interfaces físicas con RSTP funcional.**

Este rol resuelve el problema raíz que hizo fracasar las Fases 4 y 4B:

> OVS 3.3.x no permite RSTP sobre bonds.
> `ovs-vswitchd: cannot enable RSTP on bonds, disabling`

## Causa raíz

Open vSwitch 3.3.x desactiva silenciosamente RSTP en puertos de tipo bond.
Resultado en laboratorio:
- `rstp/show` tabla vacía
- Cada bridge se proclama Root Bridge
- Múltiples caminos activos sin árbol → **loops L2 → DUP! → packet loss**

## Solución implementada

Eliminar los bonds del bridge y agregar cada interfaz física como puerto OVS
independiente. RSTP opera correctamente sobre interfaces físicas individuales.

```
ANTES:  ens36 + ens37 = bond-pcsc1-sc2  →  RSTP ignorado (mensaje: disabling)
DESPUÉS: ens36 = puerto OVS normal       →  RSTP activo (forwarding/discarding)
         ens37 = puerto OVS normal       →  RSTP activo (forwarding/discarding)
```

Se conserva la redundancia física: ambos cables siguen conectados.
RSTP decide cuál está `Forwarding` y cuál `Discarding/Alternate`.

## Flujo del rol

```
1.  PRECHECK      — Validar variables, bridge y existencia de interfaces Linux
2.  BACKUP        — Guardar estado OVS y rutas antes de modificar
3.  DIAG-ANTES    — Capturar estado completo antes de tocar nada
4.  DISABLE       — Deshabilitar STP/RSTP en bridge antes de modificar topología
5.  BONDS-CLEAN   — Limpiar other_config/rstp_status de cada bond
6.  DEL-BOND      — Eliminar bonds del bridge (interfaces físicas siguen en kernel)
7.  CLEAN-IFACE   — Limpiar configuración OVS vieja en interfaces físicas
8.  ADD-PORT      — Agregar interfaces como puertos OVS + rstp-port-admin-edge=false
9.  RSTP-ON       — Configurar prioridad + rstp_enable=true (SIN reiniciar OVS)
10. WAIT          — Pausa 30s para convergencia RSTP
11. VALIDAR       — Asserts: rstp=true, prioridad, bonds ausentes, ifaces presentes
```

> [!IMPORTANT]
> **NO se reinicia `openvswitch-switch` ni la VM.**
> La configuración de `ovs-vsctl` es inmediata en OVSDB. Sin embargo,
> si la VM reinicia, los scripts de arranque OVS recrearán los bonds.
> Los scripts deben actualizarse en una fase posterior (Fase 4C.2).

## Variables requeridas en host_vars

```yaml
# Guardia principal
fase4c_nobond_rstp_enabled: true

# Bridge OVS objetivo
fase4c_bridge: "br-core"     # br-core / br-dist / br-acc

# Prioridad RSTP (múltiplo de 4096)
fase4c_rstp_priority: 4096

# Rol esperado (documentación)
fase4c_expected_role: "root-primary"

# Bonds actuales a eliminar
fase4c_deprecated_bonds:
  - name: bond-pcsc1-sc2
    members: [ens36, ens37]
  - name: bond-pcsc1-sd1
    members: [ens38, ens39]

# Interfaces físicas a agregar como puertos OVS independientes
fase4c_rstp_interfaces:
  - ens36
  - ens37
  - ens38
  - ens39

# Path costs: primer enlace del par = 100, segundo = 110
fase4c_interface_costs:
  ens36: 100
  ens37: 110
  ens38: 100
  ens39: 110

# Edge ports (accesos directos a hosts finales)
fase4c_edge_interfaces: []
```

## Tabla de prioridades Lima (Fase 4C)

| Switch       | Bridge   | Prioridad | Rol RSTP esperado           |
|---|---|---|---|
| SWCORELIM1   | br-core  | 4096      | Root Bridge principal       |
| SWCORELIM2   | br-core  | 8192      | Root Bridge secundario      |
| SWDISTLIM1   | br-dist  | 16384     | Distribución primaria       |
| SWDISTLIM2   | br-dist  | 20480     | Distribución secundaria     |
| SWACCLIM1    | br-acc   | 32768     | Acceso (nunca root)         |
| SWACCLIM2    | br-acc   | 36864     | Acceso (nunca root)         |

## Lógica de path costs

| Enlace | Cost | Razón |
|---|---|---|
| Primer enlace del par (uplink) | 100 | Preferido por RSTP |
| Segundo enlace del par (backup) | 110 | Redundante — RSTP lo pone Discarding |
| Lateral Dist↔Dist (primer enlace) | 200 | Desventajado frente a uplinks |
| Lateral Dist↔Dist (segundo enlace) | 210 | Backup del lateral |

## Qué NO toca este rol

- IP del bridge OVS (`br-core`, `br-dist`, `br-acc`)
- SVIs VLAN (`svi-vlan10`…`svi-vlan99`)
- IPs reales de SVIs
- Rutas estáticas (default via RLIM1/RLIM2)
- Keepalived / VRRP (debe estar detenido durante toda Fase 4C)
- OPNsense / RLIM1 / RLIM2
- Netplan (ens34, ens35 en Core)
- Scripts OVS de arranque (se actualizan en Fase 4C.2)
- Roles anteriores (Fase 4, 4B) — se preservan como referencia

## Rollback manual de emergencia

```bash
# Paso 1: Desactivar RSTP
sudo ovs-vsctl set bridge <bridge> rstp_enable=false
sudo ovs-vsctl clear bridge <bridge> other_config

# Paso 2: Quitar interfaces físicas del bridge
sudo ovs-vsctl --if-exists del-port <bridge> ensXX
sudo ovs-vsctl --if-exists del-port <bridge> ensYY

# Paso 3: Recrear el bond original
sudo ovs-vsctl --may-exist add-bond <bridge> <bond-name> ensXX ensYY
sudo ovs-vsctl set port <bond-name> bond_mode=active-backup
sudo ovs-vsctl set port <bond-name> lacp=off
sudo ovs-vsctl set port <bond-name> other_config:bond-primary=ensXX

# Paso 4 (si era enlace Core-Core — sin trunks):
sudo ovs-vsctl clear port <bond-name> trunks
sudo ovs-vsctl clear port <bond-name> tag
sudo ovs-vsctl clear port <bond-name> vlan_mode

# Paso 4 (si era enlace Core-Dist o Dist-Acc — con trunks):
sudo ovs-vsctl set port <bond-name> trunks=10,20,30,40,50,60,70,80,99
```

## Comparación con roles anteriores

| Capacidad | switching_rstp_fase4 | switching_l2_clean_rstp_fase4b | switching_l2_nobond_rstp_fase4c |
|---|---|---|---|
| Habilita rstp_enable bridge | ✅ | ✅ | ✅ |
| Configura prioridad bridge | ✅ | ✅ | ✅ |
| Configura puertos sobre bonds | ❌ | ✅ pero OVS lo ignora | N/A — elimina bonds |
| Elimina bonds del bridge | ❌ | ❌ | ✅ |
| Agrega interfaces físicas independientes | ❌ | ❌ | ✅ |
| RSTP funciona realmente | ❌ | ❌ | ✅ (confirmado) |
| Backup antes de migrar | ❌ | ❌ | ✅ |
| Reinicia OVS | ❌ | ⛔ Intencionalmente no | ⛔ Intencionalmente no |
