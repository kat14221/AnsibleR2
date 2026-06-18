# Arquitectura HA y Balanceo de Carga — Red Empresarial Lima (JHALEX)

> Documento de referencia técnica para la implementación por fases de alta disponibilidad,
> redundancia y balanceo de carga en la sede Lima.
> **Versión actual: FASE 4B activa. FASE 5 pendiente. FASE 6 futura.**

---

## A. Diferencia entre RLIM1/RLIM2 y SWCORELIM1/SWCORELIM2

La red Lima tiene dos capas de dispositivos redundantes que tienen roles completamente distintos:

| Dispositivo | Tipo | Función |
|---|---|---|
| **RLIM1** | Firewall/Router perimetral (OPNsense) | NAT, WAN, VPN, seguridad perimetral, salida a Internet |
| **RLIM2** | Firewall/Router perimetral (OPNsense) | Respaldo de RLIM1 — mismas funciones en failover |
| **SWCORELIM1** | Switch Core L3 (OVS + Linux) | Routing interno, gateways de VLAN, VRRP activo |
| **SWCORELIM2** | Switch Core L3 (OVS + Linux) | Routing interno, gateways de VLAN, VRRP standby/activo |

**RLIM1/RLIM2 solo hablan con los Core** a través de enlaces L3 dedicados:

```
RLIM1 ←→ (10.10.254.1/30 ↔ 10.10.254.2/30) ←→ SWCORELIM1
RLIM1 ←→ (10.10.254.5/30 ↔ 10.10.254.6/30) ←→ SWCORELIM2
RLIM2 ←→ (10.10.254.9/30 ↔ 10.10.254.10/30) ←→ SWCORELIM1
RLIM2 ←→ (10.10.254.13/30 ↔ 10.10.254.14/30) ←→ SWCORELIM2
```

Los firewalls **NO conocen las VLANs internas directamente**. Solo tienen rutas estáticas
hacia los prefijos de red de cada VLAN, apuntando a las IPs de los Core.

---

## B. Por qué los gateways de VLAN van en los Core

Los gateways de cada VLAN (las IPs a las que apuntan los hosts como `default gateway`)
deben estar en `SWCORELIM1` y `SWCORELIM2`, **NO en OPNsense/RLIM1/RLIM2**.

### Razones técnicas:

1. **Escalabilidad**: Los Core L3 están diseñados para routing interno de alta velocidad.
   OPNsense es un firewall/NAT, no un router de distribución de tráfico interno.

2. **Rendimiento**: El tráfico entre VLANs (VLAN 10 → VLAN 40, por ejemplo) no debe
   salir por el firewall perimetral. Debe ser ruteado localmente en los Core.

3. **Separación de funciones** (principio de diseño):
   - RLIM1/RLIM2: seguridad + NAT + WAN = capa perimetral
   - SWCORELIM1/2: routing interno + gateways = capa core L3

4. **Evitar router-on-a-stick**: Convertir OPNsense en gateway de todas las VLANs
   crearía un punto único de falla y congestionaría el firewall con tráfico interno
   que no necesita inspección.

5. **VRRP nativo**: Los Core Linux/OVS implementan keepalived para VRRP de forma
   nativa y eficiente. OPNsense tiene CARP pero no está diseñado para múltiples
   VIPs de distribución de carga por grupos de VLAN.

### Resultado:

```
Host VLAN 10 (192.168.10.x) → gateway 192.168.10.1 (VIP VRRP en SWCORELIM1/2)
Host VLAN 40 (192.168.40.x) → gateway 192.168.40.1 (VIP VRRP en SWCORELIM1/2)
```

Solo cuando el host necesita salir a Internet, el Core routea hacia RLIM1/RLIM2.

---

## C. Diferencia entre RSTP y VRRP

Son protocolos de capas distintas que resuelven problemas distintos:

| Protocolo | Capa OSI | Problema que resuelve | Cuándo actúa |
|---|---|---|---|
| **RSTP** | Capa 2 (Data Link) | Loops en redes Ethernet con redundancia física | En todo momento, sobre la topología L2 |
| **VRRP** | Capa 3 (Network) | Redundancia de gateway IP para los hosts | Cuando el gateway activo falla |

### RSTP (Rapid Spanning Tree Protocol)

- Actúa sobre los **bridges/switches**, no sobre las IPs.
- Calcula un árbol libre de loops bloqueando puertos redundantes.
- Cuando hay varios caminos físicos entre switches, RSTP elige uno activo
  y pone los demás en estado `Alternate` (bloqueado).
- Si el camino activo falla, el `Alternate` converge a `Designated` en ~1-2 segundos.
- **OVS implementa RSTP** configurando prioridades en el bridge y marcando los puertos
  inter-switch como `rstp-port-admin-edge=false` para intercambiar BPDUs.

### VRRP (Virtual Router Redundancy Protocol)

- Actúa sobre las **IPs de gateway**, no sobre la topología L2.
- Un router es `MASTER` (activo) y los demás son `BACKUP`.
- El `MASTER` anuncia la VIP (Virtual IP) como propia y responde a ARP.
- Si el `MASTER` falla, el `BACKUP` con mayor prioridad asume la VIP.
- En Lima, keepalived implementa VRRP en los Core L3.

### Orden obligatorio:

```
Primero RSTP (L2 estable, sin loops) → Después VRRP (L3 con gateways virtuales)
```

Si L2 tiene loops, VRRP fluctúa porque los paquetes de keepalived llegan duplicados
o no llegan, causando VRRP flapping que simula fallos de gateway inexistentes.

---

## D. Por qué primero se estabiliza L2

El orden RSTP → VRRP no es opcional, es una **dependencia técnica**:

1. **Los paquetes VRRP viajan sobre L2**: keepalived envía multicast `224.0.0.18` que
   usa la red L2 del bridge OVS. Si hay loops L2, esos paquetes se multiplican o
   se pierden aleatoriamente.

2. **VRRP flapping**: Cuando keepalived recibe múltiples copias de su propio multicast
   (por loops) puede interpretar que hay otro MASTER y entrar en conflicto de estado.

3. **Diagnóstico limpio**: Con VRRP activo durante pruebas L2 no se puede distinguir
   si el packet loss viene de un loop L2 o de un failover VRRP.

4. **Evidencia del diagnóstico actual**: Las VLANs con `DUP!` y packet loss coinciden
   con los escenarios donde hay múltiples caminos L2 activos sin RSTP controlando.

**Mientras L2 no esté limpio, keepalived permanece detenido** (Fase 4B).

---

## E. Por qué después se divide VRRP en grupos

Cuando L2 esté estable (FASE 4B completada y validada), se habilitará keepalived
con una configuración de **VRRP balanceado por grupos de VLAN** (FASE 5).

### Por qué grupos, no un único MASTER:

- Con un solo grupo VRRP (un MASTER para todas las VLANs), uno de los Core
  queda inactivo el 100% del tiempo, desperdiciando capacidad.
- Dividiendo las VLANs en dos grupos, **ambos Core trabajan activamente en paralelo**.
- Esto se denomina "Active-Active" a nivel de gateway, aunque técnicamente
  cada VRRP group tiene su propio MASTER/BACKUP.

---

## F. Tabla de Grupos VRRP — Distribución por VLAN

### Grupo A — Activo en SWCORELIM1 (BACKUP en SWCORELIM2)

| VLAN | Red | Función | VIP Gateway |
|---|---|---|---|
| VLAN 10 | 192.168.10.0/25 | Administración | 192.168.10.1 |
| VLAN 20 | 192.168.20.0/24 | Usuarios | 192.168.20.1 |
| VLAN 30 | 192.168.30.0/24 | Invitados | 192.168.30.1 |
| VLAN 70 | 192.168.70.0/27 | Monitoreo | 192.168.70.1 |
| VLAN 99 | 192.168.99.0/27 | Gestión Core | 192.168.99.1 |

### Grupo B — Activo en SWCORELIM2 (BACKUP en SWCORELIM1)

| VLAN | Red | Función | VIP Gateway |
|---|---|---|---|
| VLAN 40 | 192.168.40.0/27 | Servidores | 192.168.40.1 |
| VLAN 50 | 192.168.50.16/28 | DMZ | 192.168.50.17 |
| VLAN 60 | 192.168.60.0/25 | Voz IP | 192.168.60.1 |
| VLAN 80 | 192.168.80.0/27 | Backup/Storage | 192.168.80.1 |

---

## G. Qué pasa si cae SWCORELIM1

**En operación normal**:
- SWCORELIM1 es MASTER para el Grupo A (VLANs 10, 20, 30, 70, 99)
- SWCORELIM2 es MASTER para el Grupo B (VLANs 40, 50, 60, 80)

**Si SWCORELIM1 cae**:
1. keepalived en SWCORELIM2 detecta ausencia de anuncios VRRP del Grupo A.
2. SWCORELIM2 asciende a MASTER para el Grupo A.
3. SWCORELIM2 ahora maneja **todas las VLANs** (Grupo A + Grupo B).
4. RSTP puede reconfigurar la topología L2 si el enlace Core-Core cae junto al Core.
5. Los hosts no cambian su configuración — siguen usando la misma VIP de gateway.
6. El failover es automático, en segundos (configurable con `advert_int`).

**Impacto**: Tráfico temporal interrumpido durante la convergencia VRRP (1-3 segundos).
SWCORELIM2 absorbe toda la carga mientras SWCORELIM1 está fuera.

---

## H. Qué pasa si cae SWCORELIM2

**Si SWCORELIM2 cae**:
1. keepalived en SWCORELIM1 detecta ausencia de anuncios VRRP del Grupo B.
2. SWCORELIM1 asciende a MASTER para el Grupo B.
3. SWCORELIM1 ahora maneja **todas las VLANs** (Grupo A + Grupo B).
4. Los hosts siguen usando las mismas VIPs de gateway, sin reconfiguración.

**Impacto**: Igual que el caso anterior — failover automático en segundos.

---

## I. Por qué no implementar PVST+ ahora

**PVST+ (Per-VLAN Spanning Tree Plus) es una tecnología propietaria de Cisco.**

Las razones para NO implementarla en esta arquitectura:

1. **Incompatibilidad**: Open vSwitch NO implementa PVST+. OVS implementa
   STP (802.1D) y RSTP (802.1w) estándar. Intentar configurar "PVST+" en OVS
   es un error conceptual — no existe como tal en OVS.

2. **Codificación incorrecta**: Simular PVST+ escribiendo múltiples bridges OVS
   por VLAN sería una arquitectura artificial que no corresponde a cómo OVS
   gestiona VLANs en un bridge único.

3. **No es necesario ahora**: El objetivo actual es estabilizar L2 con RSTP estándar
   (un solo árbol spanning-tree por bridge). La separación por grupos de VLAN
   se hace con VRRP en L3, no con PVST+ en L2.

4. **Alternativa correcta para el futuro**: Si se necesita un árbol por grupo de VLANs
   en L2, la tecnología estándar sería MSTP (Multiple Spanning Tree, 802.1s),
   que OVS sí podría considerar, pero requiere análisis cuidadoso.

---

## J. Por qué MSTP queda como fase futura

**MSTP (Multiple Spanning Tree Protocol, IEEE 802.1s)** es la evolución estándar
de STP que permite agrupar VLANs en instancias (MSTIs) con topologías L2 distintas.

En la arquitectura Lima, MSTP permitiría en un futuro:
- MSTI 1: VLANs del Grupo A → árbol con root en SWCORELIM1
- MSTI 2: VLANs del Grupo B → árbol con root en SWCORELIM2

Esto complementaría el balanceo VRRP con balanceo L2 real.

**Por qué esperar para MSTP**:

1. **Complejidad adicional**: MSTP requiere configuración consistente en TODOS los
   switches de la topología. Un error en un switch puede romper múltiples VLANs.

2. **Estado actual**: OVS tiene soporte experimental para MSTP. No está maduro para
   producción en la versión actual del proyecto.

3. **Secuencia correcta**:
   ```
   FASE 4B: RSTP estable (un árbol, sin loops) ← ESTAMOS AQUÍ
   FASE 5:  VRRP balanceado por grupos         ← PRÓXIMA
   FASE 6:  Evaluar MSTP si el diseño lo justifica
   ```

4. **No urgente**: Con RSTP estable (FASE 4B) + VRRP balanceado (FASE 5),
   la red ya tendrá alta disponibilidad, redundancia y balanceo de carga efectivo.
   MSTP aportaría optimización adicional, no es condición para el funcionamiento.

---

## Resumen de Fases

| Fase | Tecnología | Estado | Criterio de avance |
|---|---|---|---|
| **4B** | RSTP limpio en OVS (bonds configurados) | **ACTIVA** | rstp/show muestra ports, sin DUP!, 0% loss |
| **5** | VRRP balanceado por grupos A/B | **PENDIENTE** | FASE 4B completa y validada |
| **6** | Evaluación MSTP / balanceo físico | **FUTURA** | FASE 5 estable en producción |

---

## Comandos de referencia rápida

### Verificar estado RSTP en Core

```bash
# En SWCORELIM1
sudo ovs-appctl rstp/show br-core
sudo ovs-vsctl get bridge br-core rstp_enable
sudo ovs-vsctl get bridge br-core other_config
sudo ovs-vsctl get port bond-pcsc1-sc2 other_config

# Ping diagnóstico Core-Core (30 paquetes)
ping -c 30 10.255.21.2
```

### Verificar estado keepalived (debe estar INACTIVO en FASE 4B)

```bash
sudo systemctl status keepalived
# Esperado: inactive (dead) durante FASE 4B
```

### Criterios de avance de FASE 4B a FASE 5

```
1. sudo ovs-appctl rstp/show br-core → tabla con puertos listados
2. SWCORELIM1 aparece como "This bridge is the root" (priority=4096)
3. SWCORELIM2 NO se autoproclamó root con Core-Core activo
4. ping -c 30 <IP_SVI_SWCORELIM2> desde SWCORELIM1 → 0% packet loss
5. No aparece DUP! en ningún ping entre IPs reales de SVIs
6. keepalived está detenido (no interfiere con pruebas L2)
```
