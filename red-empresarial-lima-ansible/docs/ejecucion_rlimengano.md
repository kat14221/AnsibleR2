# Guía de Ejecución – RLIMENGANO

> **Proyecto:** Red Empresarial Lima  
> **Documento:** Guía de Instalación y Ejecución  
> **Versión:** 1.0

---

## Requisitos Previos

| Requisito        | Versión mínima | Verificar con          |
|------------------|---------------|------------------------|
| Ubuntu Server    | 20.04 LTS+    | `lsb_release -a`       |
| Python           | 3.8+          | `python3 --version`    |
| Ansible          | 2.13+         | `ansible --version`    |
| Git              | 2.x           | `git --version`        |
| nftables         | Cualquiera    | `nft --version`        |

---

## Paso 1: Clonar el Repositorio en RLIMENGANO

Conectarse a RLIMENGANO por SSH desde la red de gestión (`172.17.25.0/24`):

```bash
ssh usuario@172.17.25.71
```

Clonar el repositorio (ajustar la URL según tu servidor Git):

```bash
# Opción A: Desde GitHub/GitLab
git clone https://github.com/TU-USUARIO/red-empresarial-lima-ansible.git
cd red-empresarial-lima-ansible

# Opción B: Copiar directamente con rsync/scp desde tu máquina de trabajo
# (Ejecutar desde tu PC Windows)
# scp -r D:\ansible\red-empresarial-lima-ansible usuario@172.17.25.71:~/
# ssh usuario@172.17.25.71
# cd red-empresarial-lima-ansible
```

---

## Paso 2: Ejecutar el Bootstrap (primera vez)

El script instala todas las dependencias necesarias:

```bash
# Dar permisos de ejecución
chmod +x scripts/bootstrap_rlimengano.sh
chmod +x scripts/run_rlimengano.sh

# Ejecutar bootstrap como root
sudo bash scripts/bootstrap_rlimengano.sh
```

El bootstrap instala:
- `git`, `curl`, `python3`, `pip3`
- `ansible` (desde PPA oficial o pip3)
- Colecciones: `ansible.posix`, `community.general`
- `nftables`, `iproute2`, `traceroute`, `tcpdump`, `dnsutils`
- Crea directorios de backup en `/root/backups/rlimengano/`

---

## Paso 3: Verificar la Configuración de Variables

Revisar las variables del dispositivo antes de ejecutar:

```bash
# Variables específicas de RLIMENGANO
cat host_vars/rlimengano.yml

# Variables globales
cat group_vars/all.yml
```

Verificar que las MACs corresponden a las interfaces reales:

```bash
ip link show ens34 | grep ether  # Debe ser 00:0c:29:19:1b:7c
ip link show ens35 | grep ether  # Debe ser 00:0c:29:19:1b:86
```

Si las MACs no coinciden, actualizar `host_vars/rlimengano.yml`.

---

## Paso 4: Ejecutar el Playbook en Modo Dry-Run (Recomendado)

Verificar qué cambios se realizarán sin aplicarlos:

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  --check --diff \
  --ask-become-pass
```

O usando el script:

```bash
bash scripts/run_rlimengano.sh --check
```

---

## Paso 5: Ejecutar el Playbook Principal

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  --ask-become-pass
```

O usando el script:

```bash
bash scripts/run_rlimengano.sh
```

Se pedirá la contraseña de `sudo` (`--ask-become-pass`).

---

## Ejecución por Tags (Parcial)

Para ejecutar solo una parte de la configuración:

```bash
# Solo hostname y paquetes
ansible-playbook -i inventories/local/hosts.yml playbooks/01_configurar_rlimengano.yml \
  --tags "hostname,packages" --ask-become-pass

# Solo configuración de red (Netplan)
ansible-playbook -i inventories/local/hosts.yml playbooks/01_configurar_rlimengano.yml \
  --tags "netplan" --ask-become-pass

# Solo nftables (NAT + Firewall)
ansible-playbook -i inventories/local/hosts.yml playbooks/01_configurar_rlimengano.yml \
  --tags "nftables" --ask-become-pass

# Solo sysctl (IPv4 Forwarding)
ansible-playbook -i inventories/local/hosts.yml playbooks/01_configurar_rlimengano.yml \
  --tags "sysctl" --ask-become-pass
```

### Tags disponibles

| Tag          | Descripción                                |
|--------------|--------------------------------------------|
| `hostname`   | Configurar nombre del sistema              |
| `packages`   | Instalar paquetes base                     |
| `netplan`    | Configurar interfaces de red               |
| `sysctl`     | Habilitar IPv4 Forwarding                  |
| `nftables`   | Configurar NAT y Firewall                  |
| `dhcp`       | Configurar/deshabilitar DHCP en ens35      |
| `validation` | Ejecutar validaciones finales              |
| `common`     | Todas las tareas del rol linux_common      |
| `nat_gateway`| Todas las tareas del rol nat_gateway       |

---

## Paso 6: Ejecutar Validaciones

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/99_validar_rlimengano.yml \
  --ask-become-pass
```

O:

```bash
bash scripts/run_rlimengano.sh --validate
```

---

## Habilitar DHCP en ens35 (Opcional)

Por defecto el DHCP está deshabilitado. Para habilitarlo:

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  --tags "dhcp" \
  --extra-vars "enable_dhcp_isp2=true" \
  --ask-become-pass
```

---

## Capturas de Evidencia (Logs)

Para guardar la salida de ejecución como evidencia:

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/01_configurar_rlimengano.yml \
  --ask-become-pass \
  2>&1 | tee /root/backups/rlimengano/logs/ejecucion-$(date +%Y%m%d-%H%M%S).log
```

Los logs de Ansible también se guardan automáticamente en `./logs/ansible.log`  
(según `ansible.cfg → log_path`).

---

## Solución de Problemas

### ens34 pierde IP después de netplan apply

```bash
# Verificar estado DHCP
ip addr show ens34
dhclient ens34   # Renovar IP DHCP manualmente

# Restaurar backup de Netplan
ls /root/backups/rlimengano/netplan/
cp /root/backups/rlimengano/netplan/ARCHIVO-BACKUP.yaml /etc/netplan/
netplan apply
```

### nftables falla al iniciar

```bash
# Verificar sintaxis
nft -c -f /etc/nftables.conf

# Ver log del servicio
journalctl -u nftables -n 50

# Restaurar ruleset limpio
nft flush ruleset
systemctl restart nftables
```

### Sin conectividad a Internet desde RLIMENGANO

```bash
# 1. Verificar interfaz WAN
ip addr show ens34
ip route show default

# 2. Verificar forwarding
sysctl net.ipv4.ip_forward  # debe ser 1

# 3. Verificar NAT
nft list ruleset | grep masquerade

# 4. Ping de diagnóstico
ping -c 4 8.8.8.8
```
