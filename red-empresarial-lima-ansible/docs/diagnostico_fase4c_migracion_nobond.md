# Diagnóstico Fase 4C — Migración No-Bond RSTP en OVS
## Red Empresarial Lima (JHALEX)

**Fecha:** 2026-06-18
**Versión OVS confirmada:** 3.3.4
**Problema raíz confirmado:** `ovs-vswitchd: cannot enable RSTP on bonds, disabling`

---

## A. Roles y playbooks RSTP existentes

| Recurso | Ruta | Estado |
|---|---|---|
| Rol Fase 4 RSTP básico | `roles/switching_rstp_fase4/` | Obsoleto — solo configura bridge, no puertos |
| Rol Fase 4B limpieza+RSTP | `roles/switching_l2_clean_rstp_fase4b/` | Obsoleto — configura puertos pero sobre bonds que OVS ignora |
| Playbooks aplicación 05_* | `playbooks/05_configurar_rstp_*.yml` | Obsoletos — usan rol Fase 4 |
| Playbooks aplicación 06_* | `playbooks/06_clean_reapply_rstp_*.yml` | Obsoletos — usan rol Fase 4B |
| Playbooks validación 99_validar_rstp_* | `playbooks/99_validar_rstp_*.yml` | Obsoletos para la nueva arquitectura |
| Playbooks validación 99_validar_nobond_rstp_* | No existen todavía | Se crearán en Fase 4C |

---

## B. Configuraciones que quedan obsoletas

### Scripts OVS de arranque (NO eliminados, sí actualizados)

| Script | Ruta | Problema |
|---|---|---|
| `jhalex-swcorelim1-ovs.sh` | `roles/swcorelim1/files/` | Crea `bond-pcsc1-sc2` y `bond-pcsc1-sd1` — OVS descarta RSTP en ellos |
| `jhalex-swcorelim2-ovs.sh` | `roles/swcorelim2/files/` | Crea `bond-pcsc1-sc2` y `bond-pcsc2-sd2` — mismo problema |
| `jhalex-swdistlim1-ovs.sh` | `roles/swdistlim1/files/` | Crea 4 bonds — RSTP ignorado |
| `jhalex-swdistlim2-ovs.sh` | `roles/swdistlim2/files/` | Crea 4 bonds — RSTP ignorado |
| `jhalex-swacclim1-ovs.sh` | `roles/swacclim1/files/` | Crea 2 bonds — RSTP ignorado |
| `jhalex-swacclim2-ovs.sh` | `roles/swacclim2/files/` | Crea 2 bonds — RSTP ignorado |

### Variables host_vars que quedan obsoletas para RSTP

Las variables FASE 4 y 4B (`rstp_inter_switch_ports`, `rstp_path_costs`) permanecen en
host_vars pero no se deben usar para la nueva arquitectura. Se agregan variables `fase4c_*`
nuevas y paralelas.

---

## C. Causa raíz: OVS no permite RSTP sobre bonds

**Evidencia directa del laboratorio:**

```text
ovs-vswitchd: cannot enable RSTP on bonds, disabling
```

**Explicación técnica:**

Open vSwitch 3.3.4 implementa RSTP (IEEE 802.1w) pero con una restricción conocida:
RSTP no puede operar sobre puertos de tipo **bond** (LAG lógico). Cuando un bond está
presente en el bridge con `rstp_enable=true`, OVS detecta el tipo de interfaz y emite
el mensaje `cannot enable RSTP on bonds, disabling`, desactivando silenciosamente RSTP
en ese puerto bond.

Consecuencia:
- `rstp/show` muestra tabla vacía o no lista los bonds
- Cada bridge se cree Root Bridge (nunca recibe BPDUs por el bond)
- Con múltiples caminos activos sin árbol STP → **loops L2 → DUP! → packet loss**

**La solución correcta para OVS 3.3.x es usar interfaces físicas individuales como puertos OVS.**
RSTP opera correctamente sobre interfaces físicas (`rstp/show` las lista, intercambia BPDUs).

---

## D. Qué se debe limpiar

### En cada switch (operación del rol Fase 4C)

1. Deshabilitar STP/RSTP en el bridge antes de modificar topología
2. Eliminar bonds del bridge (`del-port <bond>`)
3. Limpiar `other_config`, `trunks`, `tag`, `vlan_mode` de las interfaces físicas antes de agregar
4. No eliminar las interfaces Linux físicas (no hay nada que limpiar a nivel kernel)

### Scripts OVS de arranque

Los scripts `jhalex-<switch>-ovs.sh` crean bonds al arranque. Si el sistema reinicia,
volvería a crear bonds. **Los scripts deben ser actualizados** en una fase posterior (Fase 4C.2)
para reflejar la nueva topología sin bonds. Por ahora, el rol Fase 4C aplica la migración
en caliente sobre el estado OVS en memoria — sin reiniciar OVS.

> **Riesgo conocido**: Si el sistema reinicia después de Fase 4C pero antes de actualizar
> los scripts, los bonds volverán. Se documentará en la sección de riesgos.

---

## E. Qué se debe conservar

| Componente | Estado |
|---|---|
| IP `10.255.21.1/30` en `br-core` (SWCORELIM1) | ✅ Conservar |
| IP `10.255.21.2/30` en `br-core` (SWCORELIM2) | ✅ Conservar |
| SVIs VLAN (`svi-vlan10` … `svi-vlan99`) | ✅ Conservar |
| IPs reales de SVIs | ✅ Conservar |
| Rutas estáticas (default via RLIM1/RLIM2) | ✅ Conservar |
| Keepalived / VRRP | ✅ Conservar detenido |
| OPNsense / RLIM1 / RLIM2 | ✅ No tocar |
| Netplan (ens34, ens35) | ✅ No tocar |
| `fail_mode=standalone` en bridges | ✅ Conservar |
| Roles existentes (Fase 4, 4B) | ✅ No borrar — referencia histórica |
| Scripts OVS de arranque | ✅ No borrar todavía — actualizar en fase posterior |

---

## F. Archivos a crear / modificar

### CREAR

| Archivo | Descripción |
|---|---|
| `roles/switching_l2_nobond_rstp_fase4c/defaults/main.yml` | Defaults seguros |
| `roles/switching_l2_nobond_rstp_fase4c/tasks/main.yml` | Lógica completa |
| `roles/switching_l2_nobond_rstp_fase4c/README.md` | Documentación del rol |
| `playbooks/07_migrar_nobond_rstp_swcorelim1_local.yml` | Playbook local Core1 |
| `playbooks/07_migrar_nobond_rstp_swcorelim2_local.yml` | Playbook local Core2 |
| `playbooks/07_migrar_nobond_rstp_swdistlim1_local.yml` | Playbook local Dist1 |
| `playbooks/07_migrar_nobond_rstp_swdistlim2_local.yml` | Playbook local Dist2 |
| `playbooks/07_migrar_nobond_rstp_swacclim1_local.yml` | Playbook local Acc1 |
| `playbooks/07_migrar_nobond_rstp_swacclim2_local.yml` | Playbook local Acc2 |
| `playbooks/99_validar_nobond_rstp_swcorelim1_local.yml` | Validación Core1 |
| `playbooks/99_validar_nobond_rstp_swcorelim2_local.yml` | Validación Core2 |
| `playbooks/99_validar_nobond_rstp_swdistlim1_local.yml` | Validación Dist1 |
| `playbooks/99_validar_nobond_rstp_swdistlim2_local.yml` | Validación Dist2 |
| `playbooks/99_validar_nobond_rstp_swacclim1_local.yml` | Validación Acc1 |
| `playbooks/99_validar_nobond_rstp_swacclim2_local.yml` | Validación Acc2 |
| `docs/arquitectura_fase4c_nobond_rstp.md` | Documentación de arquitectura |

### MODIFICAR (solo agregar bloques FASE 4C)

| Archivo | Qué se agrega |
|---|---|
| `host_vars/swcorelim1.yml` | Variables `fase4c_*` |
| `host_vars/swcorelim2.yml` | Variables `fase4c_*` |
| `host_vars/swdistlim1.yml` | Variables `fase4c_*` |
| `host_vars/swdistlim2.yml` | Variables `fase4c_*` |
| `host_vars/swacclim1.yml` | Variables `fase4c_*` |
| `host_vars/swacclim2.yml` | Variables `fase4c_*` |

---

## G. Tabla de bonds actuales vs interfaces físicas objetivo

### SWCORELIM1 (br-core)

| Bond actual | Miembros | Destino | Nuevos puertos OVS |
|---|---|---|---|
| bond-pcsc1-sc2 | ens36, ens37 | Core2 | ens36 (cost 100), ens37 (cost 110) |
| bond-pcsc1-sd1 | ens38, ens39 | Dist1 | ens38 (cost 100), ens39 (cost 110) |

**Diferencia requerimiento vs script real:** Ninguna — mapeo coincide.

### SWCORELIM2 (br-core)

| Bond actual | Miembros | Destino | Nuevos puertos OVS |
|---|---|---|---|
| bond-pcsc1-sc2 | ens36, ens37 | Core1 | ens36 (cost 100), ens37 (cost 110) |
| bond-pcsc2-sd2 | ens41, ens40 | Dist2 | ens41 (cost 100), ens40 (cost 110) |

**Nota**: El script real usa `ens41` como primario en `bond-pcsc2-sd2`. Respetado.

### SWDISTLIM1 (br-dist)

| Bond actual | Miembros | Destino | Nuevos puertos OVS |
|---|---|---|---|
| bond-pcsc1-sd1 | ens34, ens37 | Core1 (uplink) | ens34 (cost 100), ens37 (cost 110) |
| bond-pcsd1-sd2 | ens40, ens41 | Dist2 (lateral) | ens40 (cost 200), ens41 (cost 210) |
| bond-pcsd1-sa1 | ens42, ens43 | Acc1 | ens42 (cost 100), ens43 (cost 110) |
| bond-pcsd1-sa2 | ens44, ens45 | Acc2 | ens44 (cost 100), ens45 (cost 110) |

**Diferencia requerimiento vs script:** Ninguna — mapeo coincide.

### SWDISTLIM2 (br-dist)

| Bond actual | Miembros | Destino | Nuevos puertos OVS |
|---|---|---|---|
| bond-pcsc2-sd2 | ens36, ens37 | Core2 (uplink) | ens36 (cost 100), ens37 (cost 110) |
| bond-pcsd1-sd2 | ens38, ens39 | Dist1 (lateral) | ens38 (cost 200), ens39 (cost 210) |
| bond-pcsa1-sd2 | ens40, ens41 | Acc1 | ens40 (cost 100), ens41 (cost 110) |
| bond-pcsd2-sa2 | ens42, ens43 | Acc2 | ens42 (cost 100), ens43 (cost 110) |

**Diferencia requerimiento vs script:** Ninguna — mapeo coincide.

### SWACCLIM1 (br-acc)

| Bond actual | Miembros | Destino | Nuevos puertos OVS |
|---|---|---|---|
| bond-pcsd1-sa1 | ens34, ens35 | Dist1 (preferido) | ens34 (cost 100), ens35 (cost 110) |
| bond-pcsa1-sd2 | ens36, ens37 | Dist2 (redundante) | ens36 (cost 200), ens37 (cost 210) |

**Diferencia requerimiento vs script:** Ninguna — mapeo coincide.

### SWACCLIM2 (br-acc)

| Bond actual | Miembros | Destino | Nuevos puertos OVS |
|---|---|---|---|
| bond-pcsd1-sa2 | ens34, ens35 | Dist1 (redundante) | ens34 (cost 200), ens35 (cost 210) |
| bond-pcsd2-sa2 | ens36, ens37 | Dist2 (preferido) | ens36 (cost 100), ens37 (cost 110) |

**Diferencia requerimiento vs script:** Ninguna — mapeo coincide.

---

## H. Riesgos de migración

| Riesgo | Severidad | Mitigación |
|---|---|---|
| Pérdida SSH durante migración de Core-Core | **Alta** | Usar playbooks locales en cada VM |
| Reinicio accidental de OVS invalida la migración | **Alta** | No reiniciar OVS ni la VM durante Fase 4C |
| Reinicio de la VM restaura bonds desde script de arranque | **Media** | Actualizar scripts OVS después de validar (Fase 4C.2) |
| `br-core` en SWCORELIM2 pierde IP 10.255.21.2 durante migración | **Alta** | El rol NO toca IPs del bridge — solo ports |
| VRRP/Keepalived flapping si se activa durante la migración | **Alta** | Mantener keepalived detenido durante toda Fase 4C |
| Enlace lateral Dist1↔Dist2 creando loop si se sube antes de RSTP convergir | **Media** | Seguir el orden de ejecución — Core primero, luego Dist, luego Acc |
| Hosts finales pierden gateway si SVI baja | **Baja** | SVIs no se tocan — solo puertos OVS inter-switch |

---

## I. Orden seguro de ejecución

```
1.  keepalived detenido en SWCORELIM1 y SWCORELIM2 (confirmar antes de empezar)
2.  SWCORELIM1 — migración local
3.  SWCORELIM2 — migración local (sin SSH desde Core1 — usar consola VM)
4.  Validar ping Core-Core: ping -c 30 10.255.21.2 (desde SWCORELIM1)
5.  Validar rstp/show br-core en ambos Core
6.  SWDISTLIM1 — migración local
7.  SWDISTLIM2 — migración local
8.  SWACCLIM1  — migración local
9.  SWACCLIM2  — migración local
10. Subir enlaces Core ↔ Distribución (bajarlos previamente o confirmar estado)
11. Esperar 60 segundos para convergencia RSTP
12. Validar pings reales por VLAN (ver sección 14 del requerimiento)
13. Confirmar rstp/show en todos los switches — no debe haber tabla vacía
14. Solo si todo está OK → preparar Fase 5 VRRP balanceado
```

**NO usar SSH de SWCORELIM1 a SWCORELIM2 para la migración de Core2.**
El enlace Core-Core viaja por el bond-pcsc1-sc2 que va a ser eliminado durante la migración.
Usar consola directa de la VM SWCORELIM2 en ESXi.
