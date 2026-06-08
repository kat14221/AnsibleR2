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
  playbooks/01_configurar_rlimengano.yml --ask-become-pass
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
│   └── rlimengano.yml                   # Variables específicas de RLIMENGANO
│
├── playbooks/
│   ├── 01_configurar_rlimengano.yml     # ← Playbook principal de configuración
│   └── 99_validar_rlimengano.yml        # Playbook de validación (sin cambios)
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
│   └── run_rlimengano.sh                # Script de ejecución rápida
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
  --check --diff --ask-become-pass
```

### 5. Aplicar configuración

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  --ask-become-pass
```

### 6. Validar resultado

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/99_validar_rlimengano.yml \
  --ask-become-pass
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

---

> **Autor:** Proyecto Infraestructura Red Empresarial Lima  
> **Versión:** 1.0.0 | **Última actualización:** 2026-06-08
