# 🌐 Red Empresarial Lima – Ansible

> Repositorio Ansible para la infraestructura de red empresarial híbrida – **Sede Lima**  
> Ejecución **local por dispositivo** — sin Controller externo

---

## Descripción del Proyecto

Este repositorio contiene la configuración Ansible para la infraestructura de la **Sede Lima**, compuesta por:

| Dispositivo          | Función                                          | Estado     |
|----------------------|--------------------------------------------------|------------|
| **RLIMENGANO**       | ISP secundario simulado (NAT Gateway)            | ✅ Incluido |
| RLIM1-PRINCIPAL      | Router/Firewall principal Lima                   | 🔜 Próximo |
| RLIM2-SECUNDARIO     | Router/Firewall secundario Lima                  | 🔜 Próximo |
| SWCORELIM1           | Core switch principal Lima                        | ✅ Incluido |
| SWCORELIM2           | Core switch secundario Lima                       | ✅ Incluido |
| SWDISTLIM1           | Distribución Switch 1 Lima                        | ✅ Incluido |
| SWDISTLIM2           | Distribución Switch 2 Lima                        | ✅ Incluido |
| SWACCLIM1            | Acceso Switch 1 Lima                             | ✅ Incluido |
| SWACCLIM2            | Acceso Switch 2 Lima                             | ✅ Incluido |

### Arquitectura General

```
VM Network (Internet ESXi)
        │
        │ DHCP (≈172.17.25.71)
        ▼
   ┌──────────────┐
   │  RLIMENGANO  │  ← ISP secundario simulado
   │  NAT Gateway │
   └──────────────┘
        │
        │ 10.250.20.1/24 (ens35)
        │ ENG-VM NETWORK
        ├────────────────────────┐
        │                        │
        ▼                        ▼
  RLIM1-PRINCIPAL         RLIM2-SECUNDARIO
  10.250.20.11/24         10.250.20.12/24
  GW: 10.250.20.1         GW: 10.250.20.1
```

---

## Enfoque: Ejecución Local por Dispositivo

**No se requiere una VM Ansible Controller externa.**

Cada dispositivo clona este repositorio y ejecuta solo su propio playbook:

```bash
# En RLIMENGANO:
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml -e @host_vars/rlimengano.yml -vv -K
```

---

## Estructura del Repositorio

```
red-empresarial-lima-ansible/
│
├── ansible.cfg                          # Configuración Ansible (ejecución local)
├── README.md                            # Este archivo
├── requirements.yml                     # Colecciones de Galaxy necesarias
│
├── inventories/
│   └── local/
│       └── hosts.yml                    # Inventario local (connection: local)
│
├── group_vars/
│   └── all.yml                          # Variables globales del proyecto
│
├── host_vars/
│   ├── rlimengano.yml                   # Variables específicas de RLIMENGANO
│   ├── swcorelim1.yml                   # Variables específicas de SWCORELIM1
│   └── swcorelim2.yml                   # Variables específicas de SWCORELIM2
│
├── playbooks/
│   ├── 01_configurar_rlimengano.yml     # ← Playbook principal de configuración
│   ├── 02_configurar_swcorelim1.yml     # Playbook de configuración de SWCORELIM1
│   ├── 02_configurar_swcorelim2.yml     # Playbook de configuración de SWCORELIM2
│   ├── 99_validar_rlimengano.yml        # Playbook de validación (sin cambios)
│   ├── 99_validar_swcorelim1.yml        # Validación de SWCORELIM1
│   └── 99_validar_swcorelim2.yml        # Validación de SWCORELIM2
│
├── roles/
│   ├── linux_common/                    # Rol base: hostname, paquetes, timezone
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   │
│   └── rlimengano_nat_gateway/          # Rol principal del ISP simulado
│       ├── tasks/
│       │   ├── main.yml                 # Punto de entrada (importa los demás)
│       │   ├── netplan.yml              # Configuración de interfaces de red
│       │   ├── sysctl.yml               # IPv4 Forwarding persistente
│       │   ├── nftables.yml             # NAT/PAT y Firewall
│       │   ├── dhcp_optional.yml        # DHCP opcional en ens35
│       │   └── validation.yml           # Validaciones finales del rol
│       ├── templates/
│       │   ├── 99-rlimengano-netplan.yaml.j2    # Template Netplan
│       │   ├── rlimengano-nftables.conf.j2       # Template nftables
│       │   └── dhcpd.conf.j2                     # Template DHCP (opcional)
│       ├── handlers/main.yml
│       └── defaults/main.yml
│
├── scripts/
│   ├── bootstrap_rlimengano.sh          # Instala dependencias (primera vez)
│   ├── run_rlimengano.sh                # Script de ejecución rápida
│   ├── jhalex-swcorelim1-ovs.sh         # Script OVS de SWCORELIM1
│   └── jhalex-swcorelim2-ovs.sh         # Script OVS de SWCORELIM2
│
└── docs/
    ├── direccionamiento_rlimengano.md   # Tablas de IPs y diagrama de red
    ├── ejecucion_rlimengano.md          # Guía de instalación y ejecución
    └── validaciones_rlimengano.md       # Pruebas manuales y checklist
```

---

## Inicio Rápido

### 1. Instalar dependencias (primera vez)

```bash
sudo bash scripts/bootstrap_rlimengano.sh
```

### 2. Instalar colecciones de Ansible Galaxy

```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Revisar y verificar variables

```bash
# Verificar que las MACs coincidan con las interfaces reales
ip link show ens34 | grep ether   # debe ser 00:0c:29:19:1b:7c
ip link show ens35 | grep ether   # debe ser 00:0c:29:19:1b:86
```

Si no coinciden, editar `host_vars/rlimengano.yml` con los valores correctos.

### 4. Dry-run (verificar sin aplicar)

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  -e @host_vars/rlimengano.yml -vv -K --check --diff
```

### 5. Aplicar configuración

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  -e @host_vars/rlimengano.yml -vv -K
```

### 6. Validar resultado

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/99_validar_rlimengano.yml \
  -e @host_vars/rlimengano.yml -vv -K
```

---

## Qué Configura Este Playbook

| Componente       | Configuración                                          |
|------------------|--------------------------------------------------------|
| **Hostname**     | `RLIMENGANO` (via systemd)                             |
| **ens34**        | DHCP desde VM Network, ruta por defecto                |
| **ens35**        | IP estática `10.250.20.1/24`, sin gateway              |
| **IPv4 Forward** | `net.ipv4.ip_forward=1` persistente en sysctl.d        |
| **NAT**          | nftables masquerade `10.250.20.0/24` → `ens34`         |
| **Firewall**     | nftables con reglas de input, forward y NAT            |
| **SSH**          | Solo permitido desde `172.17.25.0/24` (gestión)        |
| **DHCP**         | Deshabilitado (variable `enable_dhcp_isp2: false`)     |
| **Backups**      | Automáticos antes de cada cambio en `/root/backups/`   |
| **Logs**         | `./logs/ansible.log` + capturas opcionales             |

### Distribución y Acceso (Nueva Topología)

| Componente       | Configuración                                          |
|------------------|--------------------------------------------------------|
| **SWDISTLIM1**    | Distribución Switch 1: Core1, Dist2, Acc1, Acc2         |
| **SWDISTLIM2**    | Distribución Switch 2: Core2, Dist1, Acc1, Acc2         |
| **SWACCLIM1**     | Acceso Switch 1: Dist1, Dist2                       |
| **SWACCLIM2**     | Acceso Switch 2: Dist1, Dist2                       |

---

## Variables Clave

| Variable              | Valor por defecto  | Descripción                          |
|-----------------------|--------------------|--------------------------------------|
| `wan_interface`       | `ens34`            | Interfaz WAN (DHCP)                  |
| `lan_interface`       | `ens35`            | Interfaz LAN (estática)              |
| `lan_ip`              | `10.250.20.1`      | IP de ens35                          |
| `management_network`  | `172.17.25.0/24`   | Red donde se permite SSH             |
| `nat_enabled`         | `true`             | Habilitar NAT masquerade             |
| `enable_dhcp_isp2`    | `false`            | Habilitar DHCP en ens35              |

---

## Ejecución por Tags

```bash
# Solo red (Netplan)
--tags netplan

# Solo IPv4 Forwarding
--tags sysctl

# Solo NAT + Firewall
--tags nftables

# Solo validaciones
--tags validation
```

---

## Seguridad

- ✅ Sin contraseñas hardcodeadas en el repositorio
- ✅ Sin claves privadas en el repositorio
- ✅ Backups automáticos antes de modificar red/firewall
- ✅ ens34 protegida: nunca se toca de forma destructiva
- ✅ SSH restringido a la red de gestión
- ✅ Firewall con política DROP por defecto

---

## Documentación

| Documento | Descripción |
|-----------|-------------|
| [docs/direccionamiento_rlimengano.md](docs/direccionamiento_rlimengano.md) | Tablas de IPs, diagrama, reglas de firewall |
| [docs/ejecucion_rlimengano.md](docs/ejecucion_rlimengano.md) | Guía paso a paso de instalación y ejecución |
| [docs/validaciones_rlimengano.md](docs/validaciones_rlimengano.md) | Pruebas manuales desde RLIM1/RLIM2, checklist |

---

## Próximos Dispositivos

- `02_configurar_rlim1.yml` — RLIM1-PRINCIPAL (router/firewall principal)
- `03_configurar_rlim2.yml` — RLIM2-SECUNDARIO (router/firewall secundario)

### Distribución y Acceso (Implementación Completa)

- `02_configurar_swdistlim1.yml` — SWDISTLIM1 (Distribución Switch 1)
- `02_configurar_swdistlim2.yml` — SWDISTLIM2 (Distribución Switch 2)
- `02_configurar_swacclim1.yml` — SWACCLIM1 (Acceso Switch 1)
- `02_configurar_swacclim2.yml` — SWACCLIM2 (Acceso Switch 2)

- `99_validar_swdistlim1.yml` — Validación de SWDISTLIM1
- `99_validar_swdistlim2.yml` — Validación de SWDISTLIM2
- `99_validar_swacclim1.yml` — Validación de SWACCLIM1
- `99_validar_swacclim2.yml` — Validación de SWACCLIM2

---

## Fase 3 — Core L3 (SVIs + VRRP + rutas)

### Advertencias (obligatorio antes de ejecutar)

- Confirmar snapshot/backup de SWCORELIM1 y SWCORELIM2.
- No ejecutar si fallan los ping hacia RLIM1/RLIM2.
- No ejecutar si `br-core` no existe.
- No ejecutar si no existen los bonds de Fase 2 (`bond-pcsc1-sd1`, `bond-pcsc2-sd2`, `bond-pcsc1-sc2`).
- **NUNCA usar `-e core_l3_enabled=true` como workaround.** Las variables deben estar completas en `host_vars/`.
- **NUNCA usar `-e @host_vars/swcorelimX.yml`.** Los playbooks cargan las variables explícitamente.

### Causa raíz del error `default_routes is defined and (default_routes | length) > 0`

Ansible carga `host_vars/<hostname>.yml` automáticamente **solo si `inventory_hostname` coincide exactamente con el nombre del archivo**. Si el hostname del SO es distinto al nombre en el inventario, o si el playbook corre desde un controller remoto sin el inventario correcto, Ansible usa los `defaults/main.yml` del rol (`default_routes: []`) y el assert falla.

**Solución estructural:** todos los playbooks Core L3 usan `include_vars` explícito en `pre_tasks` para forzar la carga correcta.

### Preparación desde Windows

```bash
git status
git add playbooks/00_preflight_core_l3_vars.yml \
        playbooks/04_migrar_core_l3_vrrp_estable.yml \
        playbooks/03_configurar_swcorelim1_l3.yml \
        playbooks/03_configurar_swcorelim2_l3.yml \
        playbooks/03_configurar_core_l3_fase3.yml \
        roles/core_l3_fase3/tasks/main.yml \
        README.md
git commit -m "fix: carga explicita host vars y preflight core l3"
git push
```

### Actualizar el repo en el equipo ejecutor

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
BRANCH=$(git branch --show-current)
git status
git pull --rebase origin $BRANCH
```

### Verificaciones previas

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
ansible-playbook --version
ansible -i inventories/local/hosts.yml swcorelim1 -m ping -k -K
ansible -i inventories/local/hosts.yml swcorelim2 -m ping -k -K
```

### ORDEN SEGURO DE EJECUCIÓN

```bash
# ─────────────────────────────────────────────────────────────────────────
# PASO 1 — Verificar variables ANTES de tocar servicios (solo lectura)
# ─────────────────────────────────────────────────────────────────────────
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/00_preflight_core_l3_vars.yml -vv -k

# ─────────────────────────────────────────────────────────────────────────
# PASO 2 — Syntax-check (no ejecuta nada en remoto)
# ─────────────────────────────────────────────────────────────────────────
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/00_preflight_core_l3_vars.yml --syntax-check

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/04_migrar_core_l3_vrrp_estable.yml --syntax-check

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_vlans_core_l3_fase3.yml --syntax-check

# ─────────────────────────────────────────────────────────────────────────
# PASO 3 — Ejecutar migración limpia (solo si pasos 1 y 2 son OK)
# ─────────────────────────────────────────────────────────────────────────
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/04_migrar_core_l3_vrrp_estable.yml -vv -k -K

# ─────────────────────────────────────────────────────────────────────────
# PASO 4 — Validar todas las VLANs tras migración
# ─────────────────────────────────────────────────────────────────────────
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_vlans_core_l3_fase3.yml -vv -k -K
```

### Flujo manual alternativo (host por host)

```bash
# Aplicar primero SWCORELIM1:
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/03_configurar_swcorelim1_l3.yml -vv -k -K

# Validar SWCORELIM1:
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swcorelim1_l3.yml -vv -k -K

# Aplicar SWCORELIM2:
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/03_configurar_swcorelim2_l3.yml -vv -k -K

# Validar SWCORELIM2:
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swcorelim2_l3.yml -vv -k -K

# Validación final ambos Core:
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_core_l3_fase3.yml -vv -k -K
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_vlans_core_l3_fase3.yml -vv -k -K
```

### Criterios de éxito

- Keepalived activo en ambos Core.
- SWCORELIM1 (MASTER, prioridad 150) mantiene todos los VIPs.
- SWCORELIM2 (BACKUP, prioridad 100) no mantiene VIPs mientras SWCORELIM1 esté activo.
- SVIs presentes en ambos Core y `ip_forward=1`.
- VIPs responden sin pérdida: `192.168.20.1`, `192.168.40.1`, `192.168.80.1`.
- Conectividad a Internet desde ambos Core: `ping 8.8.8.8`.
- No se elimina ni modifica ningún bond/trunk de Fase 2.

---

> **Autor:** Proyecto Infraestructura Red Empresarial Lima
> **Versión:** 1.1.0 | **Última actualización:** 2026-06-18


### Preparación desde OpenCode/Windows

```bash
git status
git add roles/core_l3_fase3 playbooks host_vars/swcorelim1.yml host_vars/swcorelim2.yml README.md
git commit -m "migra vrrp core l3 a instancia unica y automatiza validacion"
git push
```

### Actualizar el repo en el equipo ejecutor

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
BRANCH=$(git branch --show-current)
git status
git pull --rebase origin $BRANCH
```

### Verificaciones previas desde un solo equipo ejecutor Ansible

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
ansible-playbook --version
ansible -i inventories/local/hosts.yml swcorelim1 -m ping -K
ansible -i inventories/local/hosts.yml swcorelim2 -m ping -K
```

### Syntax-check obligatorio

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/03_configurar_swcorelim1_l3.yml --syntax-check -e @host_vars/swcorelim1.yml
ansible-playbook -i inventories/local/hosts.yml playbooks/03_configurar_swcorelim2_l3.yml --syntax-check -e @host_vars/swcorelim2.yml
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_swcorelim1_l3.yml --syntax-check -e @host_vars/swcorelim1.yml
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_swcorelim2_l3.yml --syntax-check -e @host_vars/swcorelim2.yml
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_core_l3_fase3.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_vlans_core_l3_fase3.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/04_migrar_core_l3_vrrp_estable.yml --syntax-check
```

### Aplicación recomendada

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/04_migrar_core_l3_vrrp_estable.yml -vv -K
```

### Validación final

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_vlans_core_l3_fase3.yml -vv -K
```

### Flujo manual alternativo

```bash
# Aplicar primero SWCORELIM1:
ansible-playbook -i inventories/local/hosts.yml playbooks/03_configurar_swcorelim1_l3.yml -e @host_vars/swcorelim1.yml -vv -K

# Validar SWCORELIM1:
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_swcorelim1_l3.yml -e @host_vars/swcorelim1.yml -vv -K

# Aplicar SWCORELIM2:
ansible-playbook -i inventories/local/hosts.yml playbooks/03_configurar_swcorelim2_l3.yml -e @host_vars/swcorelim2.yml -vv -K

# Validar SWCORELIM2:
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_swcorelim2_l3.yml -e @host_vars/swcorelim2.yml -vv -K

# Validación final ambos Core:
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_core_l3_fase3.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_vlans_core_l3_fase3.yml -vv -K
```

### Criterios de éxito

- Keepalived activo en ambos Core.
- SWCORELIM1 mantiene normalmente todos los VIPs.
- SWCORELIM2 no mantiene los VIPs mientras SWCORELIM1 esté activo.
- SVIs presentes en ambos Core y `ip_forward=1`.
- VIPs responden sin pérdida: `192.168.20.1`, `192.168.40.1`, `192.168.80.1`.
- Conectividad a Internet desde ambos Core: `ping 8.8.8.8`.
- No se elimina ni modifica ningún bond/trunk de Fase 2.

---

> **Autor:** Proyecto Infraestructura Red Empresarial Lima
> **Versión:** 1.2.0 | **Última actualización:** 2026-06-18

---

## Fase 4 — RSTP Switching (Open vSwitch)

### Estado inicial requerido antes de aplicar Fase 4

> ⚠️ **`keepalived` debe permanecer DETENIDO en SWCORELIM1 y SWCORELIM2 hasta validar RSTP.**

Los siguientes enlaces están temporalmente abajo para diagnóstico L2 y deben mantenerse así hasta que RSTP esté configurado en todos los switches:

```text
SWCORELIM1: ens38, ens39  (hacia SWDISTLIM1)
SWCORELIM2: ens40, ens41  (hacia SWDISTLIM2)
```

### Prioridades RSTP por switch

| Switch       | Bridge   | Prioridad | Rol                     |
|---|---|---|---|
| SWCORELIM1   | br-core  | 4096      | Root Bridge principal   |
| SWCORELIM2   | br-core  | 8192      | Root Bridge secundario  |
| SWDISTLIM1   | br-dist  | 16384     | Distribución primaria   |
| SWDISTLIM2   | br-dist  | 20480     | Distribución secundaria |
| SWACCLIM1    | br-acc   | 32768     | Acceso                  |
| SWACCLIM2    | br-acc   | 36864     | Acceso                  |

### Paso 1 — Preparar y pushear desde Windows/OpenCode

```bash
git status
git add roles/switching_rstp_fase4 playbooks host_vars README.md
git commit -m "fase4 habilita rstp en switching ovs lima"
git push
```

### Paso 2 — git pull en cada VM switch

En cada VM (swcorelim1, swcorelim2, swdistlim1, swdistlim2, swacclim1, swacclim2):

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
git pull --rebase origin main
```

### Paso 3 — Aplicar RSTP en Core desde SWCORELIM1

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible

# Syntax-check (no ejecuta nada en remoto)
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_core.yml --syntax-check

# Aplicar RSTP en SWCORELIM1 y SWCORELIM2
# NO usar -k (ya hay llave SSH hacia SWCORELIM2). Usar -K para sudo.
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_core.yml -vv -K

# Validar
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_rstp_core.yml -vv -K
```

### Paso 4 — Aplicar RSTP en distribución (localmente en cada VM)

**En SWDISTLIM1:**

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swdistlim1_local.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swdistlim1_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_rstp_swdistlim1_local.yml -vv -K
```

**En SWDISTLIM2:**

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swdistlim2_local.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swdistlim2_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_rstp_swdistlim2_local.yml -vv -K
```

### Paso 5 — Aplicar RSTP en acceso (localmente en cada VM)

**En SWACCLIM1:**

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swacclim1_local.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swacclim1_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_rstp_swacclim1_local.yml -vv -K
```

**En SWACCLIM2:**

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swacclim2_local.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/05_configurar_rstp_swacclim2_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_rstp_swacclim2_local.yml -vv -K
```

### Paso 6 — Rehabilitar enlaces hacia distribución (solo si RSTP aplicado en TODOS)

**En SWCORELIM1:**

```bash
sudo ip link set ens38 up
sudo ip link set ens39 up
```

**En SWCORELIM2:**

```bash
sudo ip link set ens40 up
sudo ip link set ens41 up
```

Esperar convergencia RSTP:

```bash
sleep 60
```

### Paso 7 — Validar estabilidad L2 con keepalived todavía DETENIDO

```bash
# Desde SWCORELIM1:
ping -c 30 10.255.21.2
ping -I svi-vlan10 -c 10 192.168.10.126
ping -I svi-vlan20 -c 10 192.168.20.254
ping -I svi-vlan30 -c 10 192.168.30.254
ping -I svi-vlan40 -c 10 192.168.40.30
ping -I svi-vlan60 -c 10 192.168.60.126
ping -I svi-vlan80 -c 10 192.168.80.30
ping -I svi-vlan99 -c 10 192.168.99.12
```

**Criterio:** 0% packet loss (se acepta 1 paquete perdido por ARP inicial, NO pérdida sostenida).

### Paso 8 — Levantar Keepalived (solo si L2 es estable)

**En SWCORELIM1:**

```bash
sudo systemctl start keepalived
sudo systemctl status keepalived --no-pager
```

**En SWCORELIM2 (desde SWCORELIM1):**

```bash
ssh adminred@10.255.21.2
sudo systemctl start keepalived
sudo systemctl status keepalived --no-pager
exit
```

Esperar convergencia VRRP:

```bash
sleep 30
```

### Paso 9 — Validar VRRP

```bash
ping -I svi-vlan20 -c 10 192.168.20.1
ping -I svi-vlan40 -c 10 192.168.40.1
ping -I svi-vlan80 -c 10 192.168.80.1

sudo journalctl -u keepalived -n 100 --no-pager \
  | egrep "VI_LIMA_CORE|MASTER|BACKUP|FAULT|priority|advert"

ssh adminred@10.255.21.2 \
  'sudo journalctl -u keepalived -n 100 --no-pager \
   | egrep "VI_LIMA_CORE|MASTER|BACKUP|FAULT|priority|advert"'
```

**Criterios:**
- SWCORELIM1 → MASTER (prioridad 150)
- SWCORELIM2 → BACKUP (prioridad 100)
- Sin flapeo MASTER/BACKUP repetitivo
- VIPs responden sin pérdida

### Rollback manual de RSTP

Si RSTP genera problemas en cualquier bridge, desactivar:

```bash
# Core
sudo ovs-vsctl set bridge br-core rstp_enable=false

# Distribución
sudo ovs-vsctl set bridge br-dist rstp_enable=false

# Acceso
sudo ovs-vsctl set bridge br-acc rstp_enable=false
```

---

> **Autor:** Proyecto Infraestructura Red Empresarial Lima
> **Versión:** 1.2.0 | **Última actualización:** 2026-06-18

---

## Fase 4C — Migración a Enlaces Físicos (No-Bond RSTP)

### Estado inicial requerido antes de aplicar Fase 4C

> ⚠️ **`keepalived` debe permanecer DETENIDO en SWCORELIM1 y SWCORELIM2 durante toda esta fase.**

Los enlaces hacia distribución pueden estar activos, pero se recomienda la siguiente secuencia para evitar bucles.

### Causa de la Migración
OVS 3.3.x no permite habilitar RSTP sobre interfaces lógicas tipo `bond`. El bridge ignoraba el protocolo de redundancia, generando bucles L2. En la Fase 4C, se desmantelan los bonds y se usan los dos enlaces físicos como puertos OVS individuales administrados directamente por RSTP.

- **Fase 4B (RSTP OVS)**: Roles `switching_l2_clean_rstp_fase4b` y variables asociadas para establecer Root bridges L2 y prioridades.
- **Fase 4C (No-Bond RSTP)**: Eliminación de bonds y migración a interfaces físicas independientes para soportar RSTP en OVS.
- **Fase 4C.2 (Safe Standby & Failover)**: Persistencia de topología segura sin bucles y habilitación de failover manual coordinado mediante CLI local, debido a las limitaciones de RSTP en entornos virtualizados.
- **Fase 5 (VRRP / Keepalived Balanceado)**: Configuración de alta disponibilidad Activo/Activo para ruteo L3. El tráfico de las VLANs se balancea entre SWCORELIM1 (Grupo A) y SWCORELIM2 (Grupo B) empleando VRRP unicast sobre las interfaces SVI.
- **Fase 6A (Uplink Trunk H2)**: Habilitación del enlace de red `ens41` en modo trunk desde `SWACCLIM1` hacia el Hypervisor ESXi H2, otorgando visibilidad a las VMs de Servicios.

### Configuración del Laboratorio Windows (Fase 7 Local)
- **FASE 7 LOCAL — DC DNS DHCP Lima Windows Server 2025**: Despliegue de los servicios base de infraestructura (AD, DNS, DHCP) 100% automatizados con PowerShell local (sin WinRM ni Ansible remoto) para asegurar un aprovisionamiento ininterrumpido en la VM `DC-DNS-DHCP-LIMA`.
  - **Ejecución local en la VM Windows**:
    ```powershell
    mkdir C:\JHALEX
    cd C:\JHALEX
    git clone https://github.com/kat14221/AnsibleR2.git
    cd C:\JHALEX\AnsibleR2\red-empresarial-lima-ansible\windows\dc_dns_dhcp_lima_local
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\Run-Fase7-Menu.ps1
    ```

### Fase 8: Servicios L3 Adicionales
- **FASE 8 — DHCP Relay en SWCORELIM1 y SWCORELIM2 hacia LIM-DC01**: Implementación de `isc-dhcp-relay` en los switches Core para interceptar y reenviar como tráfico Unicast las peticiones DHCP generadas en las distintas VLANs (10, 20, 30, 60, 70, 80, 99) hacia el Domain Controller alojado en la VLAN 40.

### Fase 9: Servidores de Archivos y Backup
- **FASE 9 — Servidor de archivos y backup local Lima**: Despliegue de servidor de archivos autónomo en Ubuntu Server 24.04 LTS (VLAN 80) utilizando Samba/CIFS. Provee compartición granular de directorios (ADMIN y CLIENTES) soportado por permisos ACL, IP estática, y seguridad de usuarios `nologin`.
- **FASE 9B — Integración al Dominio AD**: Transición del servidor Samba standalone a Member Server del dominio `jhalex.local` usando Kerberos (`krb5`) y Winbind. Delega la autenticación de usuarios de red a Windows Server y mapea grupos del AD (`GG-JHALEX-ADMIN-EMPRESA`, `GG-JHALEX-CLIENTES-LIMA`) hacia ACLs extendidas en Linux (`acl_xattr`).

### Fase 10: Monitoreo Empresarial
- **FASE 10 — Servidor de Monitoreo MON-ZABBIX-LIMA**: Despliegue de Zabbix 7.0 LTS en Ubuntu Server 26.04 LTS (VLAN 70). Implementa el Server, Frontend web (Apache/PHP) y Agent 2, utilizando base de datos PostgreSQL 16 para garantizar rendimiento histórico óptimo.
- **FASE 10B — UX Max Zabbix UI Enhancement (Opcional)**: Instalación del módulo UX Max para mejorar la experiencia visual y funcional del frontend de Zabbix (requiere validación previa de la Fase 10 y habilitación manual desde la interfaz de administración).

### Configuración del Laboratorio L3 y Firewall (Fase 3 y Perimetral)

### Paso 1 — Preparar y pushear desde Windows/OpenCode

```bash
git add roles/switching_l2_nobond_rstp_fase4c playbooks host_vars docs README.md
git commit -m "fase4c migra bonds a enlaces fisicos rstp en ovs"
git push
```

### Paso 2 — git pull en cada VM switch

En cada VM (swcorelim1, swcorelim2, swdistlim1, swdistlim2, swacclim1, swacclim2):

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
git pull --rebase origin main
```

### Paso 3 — Aplicar Migración en Core

> ⚠️ **NO USAR SSH desde SWCORELIM1 a SWCORELIM2**. El enlace Core-Core se interrumpirá durante la migración. Utiliza la consola de la VM (ESXi).
> ⚠️ **ENLACES CORE-DISTRIBUCIÓN DOWN**: Durante esta ejecución en los Core, los enlaces hacia Distribución (`ens38`, `ens39` en Core1; `ens40`, `ens41` en Core2) no se levantan automáticamente. Esto es intencional para evitar bucles.

**En SWCORELIM1:**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swcorelim1_local.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swcorelim1_local.yml -vv -K
```

**En SWCORELIM2 (Consola ESXi):**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swcorelim2_local.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swcorelim2_local.yml -vv -K
```

**Validar (Core):**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_nobond_rstp_swcorelim1_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_nobond_rstp_swcorelim2_local.yml -vv -K
```


### Paso 4 — Aplicar Migración en Distribución

**En SWDISTLIM1:**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swdistlim1_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_nobond_rstp_swdistlim1_local.yml -vv -K
```

**En SWDISTLIM2:**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swdistlim2_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_nobond_rstp_swdistlim2_local.yml -vv -K
```

### Paso 5 — Aplicar Migración en Acceso

**En SWACCLIM1:**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swacclim1_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_nobond_rstp_swacclim1_local.yml -vv -K
```

**En SWACCLIM2:**
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/07_migrar_nobond_rstp_swacclim2_local.yml -vv -K
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_nobond_rstp_swacclim2_local.yml -vv -K
```

### Paso 6 — Verificaciones

Después de migrar y reconectar todos los enlaces (esperar 60s), desde `SWCORELIM1` verificar que RSTP vea las interfaces y probar ping:

```bash
ping -c 30 10.255.21.2
sudo ovs-appctl rstp/show br-core | sed -n '1,220p'
```
Y hacia las SVIs:
```bash
ping -I svi-vlan10 -c 10 192.168.10.126
# (Ver requerimiento Fase 4C para lista completa de IPs)
```
Si la red L2 es estable (0% loss, sin DUP!), se puede preparar la **Fase 5 (VRRP balanceado)**.

### Rollback (Manual)

Si es necesario revertir:
1. `sudo ovs-vsctl set bridge <bridge> rstp_enable=false`
2. `sudo ovs-vsctl --if-exists del-port <bridge> ensXX`
3. `sudo ovs-vsctl --may-exist add-bond <bridge> <bond> ensXX ensYY bond_mode=active-backup`
4. Restaurar configuración OVS (`other_config`, etc). Ver README en rol `switching_l2_nobond_rstp_fase4c`.
