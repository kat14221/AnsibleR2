# Arquitectura Fase 4C — Migración a No-Bond RSTP

**Proyecto**: Red Empresarial Lima (JHALEX)
**Fecha**: 2026-06-18
**Autor**: Arquitecto Senior de Redes (Ansible Agent)

---

## 1. Contexto y Problema Raíz

Durante la Fase 4 y 4B, se intentó habilitar RSTP sobre una topología que agrupaba los enlaces físicos (ens36+ens37, ens38+ens39, etc.) en **bonds** (LAG - Link Aggregation Groups) gestionados por Open vSwitch.

El objetivo era tener balanceo de carga L2 nativo y tolerancia a fallos por bond, sumado a la prevención de loops de RSTP entre los diferentes equipos.

### El Error Confirmado
En la práctica, OVS 3.3.4 (y versiones 3.x) implementa RSTP de acuerdo al estándar 802.1w pero **no permite habilitarlo sobre puertos de tipo bond**. 

Evidencia directa del syslog de `ovs-vswitchd`:
```text
cannot enable RSTP on bonds, disabling
```

### Consecuencia del Error
Al desactivarse silenciosamente RSTP en los puertos bond:
1. Ningún switch enviaba ni recibía BPDUs (Bridge Protocol Data Units) a través de esos puertos.
2. Cada bridge OVS (`br-core`, `br-dist`, `br-acc`) se consideraba a sí mismo como el Root Bridge.
3. Al existir múltiples caminos físicos entre los switches (topología mallada), y al no haber bloqueo de puertos por RSTP, se formaron **loops L2 de broadcast**.
4. Esto resultó en paquetes duplicados (DUP!) y pérdida masiva de conectividad (packet loss).

---

## 2. Nueva Arquitectura L2: Enlaces Físicos Independientes

Para resolver esto sin perder redundancia física, la **Fase 4C** desmantela los bonds lógicos a nivel de OVS y expone directamente los enlaces físicos como puertos OVS individuales administrados por RSTP.

### A. Por qué se mantienen dos enlaces físicos
Mantener ambos cables (ej. `ens36` y `ens37`) asegura:
- Tolerancia a fallos físicos: si un cable o puerto NIC se daña, el otro sigue disponible.
- Capacidad de enlace de respaldo (Backup path) inmediata.

### B. Por qué se eliminan los bonds lógicos
Eliminamos el bond en OVS para que RSTP pueda ver e interactuar con cada enlace físico por separado. De esta forma, OVS ya no bloquea RSTP con el error `cannot enable RSTP on bonds`.

### C. Cómo RSTP bloquea enlaces redundantes
RSTP evaluará todos los caminos disponibles hacia el Root Bridge (SWCORELIM1). Para cada par de enlaces entre dos switches:
- **Enlace 1 (Cost 100)**: Será elegido por RSTP como `Designated` o `Root` y se pondrá en estado **Forwarding**.
- **Enlace 2 (Cost 110)**: Al tener mayor costo, RSTP lo marcará como `Alternate` o `Backup` y lo pondrá en estado **Discarding** (bloqueado lógicamente).

Si el Enlace 1 falla, RSTP convergirá rápidamente y pasará el Enlace 2 a estado **Forwarding**.

### D. Qué se pierde
Se pierde el **balanceo físico por cable** (hash L2/L3/L4) que ofrecía el bond activo-activo. Todo el tráfico L2 fluirá por un solo cable (el Enlace 1) a la vez.

### E. Qué se conserva
- **Redundancia y failover L2**: Si un cable cae, RSTP levanta el otro.
- Prevención real y garantizada de bucles L2 (Broadcast Storms).
- Priorización jerárquica estricta (Core1 > Core2 > Dist1 > Dist2 > Acc).

### F. Por qué el balanceo se hará luego en Capa 3
El balanceo de carga que se pierde en L2 se recuperará en L3 usando **VRRP balanceado por grupos de VLANs** (Fase 5):
- VRRP Grupo 1 (VLANs 10,20,30,40) usará SWCORELIM1 como Master.
- VRRP Grupo 2 (VLANs 50,60,70,80,99) usará SWCORELIM2 como Master.
Esto asegura que ambos switches Core y ambos caminos hacia Distribución se utilicen activamente.

---

## 3. Topología Fase 4C L2-Lógica

```mermaid
graph TD
    %% Core
    C1[SWCORELIM1 (Root 4096)]
    C2[SWCORELIM2 (Sec 8192)]
    
    %% Distribución
    D1[SWDISTLIM1 (16384)]
    D2[SWDISTLIM2 (20480)]
    
    %% Acceso
    A1[SWACCLIM1 (32768)]
    A2[SWACCLIM2 (36864)]

    %% Conexiones (se ilustran los dos enlaces físicos)
    C1 -- ens36/Fwd \n ens37/Blk --> C2
    C1 -- ens38/Fwd \n ens39/Blk --> D1
    
    C2 -- ens41/Fwd \n ens40/Blk --> D2
    
    D1 -- ens40/Blk \n ens41/Blk --> D2
    
    D1 -- ens42/Fwd \n ens43/Blk --> A1
    D1 -- ens44/Fwd \n ens45/Blk --> A2
    
    D2 -- ens40/Blk \n ens41/Blk --> A1
    D2 -- ens42/Blk \n ens43/Blk --> A2
```
*Nota: Fwd = Forwarding, Blk = Discarding/Alternate (bloqueado por RSTP). Los enlaces laterales/redundantes estarán bloqueados por defecto hasta que ocurra un fallo.*

---

## 4. Orden de Implementación

La migración es disruptiva a nivel L2 y debe hacerse paso a paso localmente en cada VM:

1. **Mantener Keepalived APAGADO**: Obligatorio para evitar flapeos VRRP durante los cortes L2.
2. **SWCORELIM1 (Local)**: Migración Core1.
3. **SWCORELIM2 (Local)**: Migración Core2. *(Atención: No usar SSH desde Core1 hacia Core2, el enlace se cortará. Usar consola ESXi).*
4. **Validar Core-Core**: Comprobar convergencia RSTP entre ambos cores.
5. **SWDISTLIM1 y SWDISTLIM2 (Local)**.
6. **SWACCLIM1 y SWACCLIM2 (Local)**.
7. **Subir enlaces Core ↔ Distribución** (si estaban bajados).
8. **Esperar 60s y validar L2 (pings entre SVIs y Hosts)**.
9. **Fase 5 (VRRP)**: Solo proceder si L2 es estable sin DUP! ni packet loss.

---

## 5. Rollback Manual

La Fase 4C elimina los bonds del OVSDB dinámicamente pero **NO** borra las configuraciones base ni los scripts de arranque. En caso de fallo crítico:

1. Desactivar RSTP en el bridge involucrado:
   ```bash
   sudo ovs-vsctl set bridge br-<nombre> rstp_enable=false
   ```
2. Recrear el bond manual o simplemente **reiniciar la VM**. Al reiniciar, el script de arranque original (ej. `jhalex-swcorelim1-ovs.sh`) se ejecutará, recreando los bonds iniciales.

*(La actualización de los scripts de arranque para hacer persistente la Fase 4C se realizará en la Fase 4C.2, una vez validada la estabilidad).*
