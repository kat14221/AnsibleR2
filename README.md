# 🌐 Ansible Network Automation Lab

> Proyecto profesional de automatización de redes con Ansible para entorno virtualizado en VMware.  
> Soporta Cisco IOS, IOS-XE, IOS-XR y Fortinet FortiOS.

---

## 📋 Tabla de Contenidos

- [Requisitos](#-requisitos)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Instalación](#-instalación)
- [Configuración de Inventario](#-configuración-de-inventario)
- [Uso de Vault (Credenciales)](#-uso-de-vault-credenciales)
- [Playbooks Disponibles](#-playbooks-disponibles)
- [Roles](#-roles)
- [Tags Disponibles](#-tags-disponibles)
- [Ejemplos de Uso](#-ejemplos-de-uso)

---

## 🔧 Requisitos

| Herramienta       | Versión Mínima |
|-------------------|----------------|
| Python            | 3.9+           |
| Ansible           | 2.15+          |
| ansible-core      | 2.15+          |

### Dependencias de Sistema

```bash
# Linux/WSL (recomendado para Windows)
pip install ansible
pip install ansible-pylibssh   # Para SSH en dispositivos de red
pip install paramiko           # Alternativa SSH

# Instalar colecciones de Galaxy
ansible-galaxy collection install -r requirements.yml
```

---

## 📁 Estructura del Proyecto

```
ansible/
├── ansible.cfg                    # Configuración principal
├── requirements.yml               # Colecciones de Galaxy
├── .gitignore
│
├── inventories/
│   ├── lab/                       # Entorno de laboratorio VMware
│   │   ├── hosts.yml
│   │   └── group_vars/
│   └── production/                # Entorno de producción
│
├── group_vars/all/
│   ├── main.yml                   # Variables globales
│   └── vault.yml                  # 🔒 Credenciales cifradas
│
├── host_vars/                     # Variables por dispositivo
│   ├── R1.yml
│   ├── R2.yml
│   └── FW1.yml
│
├── roles/
│   ├── common/                    # Hostname, NTP, DNS, Banner
│   ├── interfaces/                # IPs, VLANs
│   ├── routing/                   # OSPF, BGP, EIGRP
│   ├── acl/                       # Access Control Lists
│   ├── security_hardening/        # SSH, AAA, Hardening
│   ├── user_management/           # Usuarios locales
│   ├── backup/                    # Backup & Restore
│   └── monitoring/                # Validación y reportes
│
├── playbooks/
│   ├── site.yml                   # 🎯 Playbook maestro
│   ├── deploy_topology.yml        # Despliegue completo
│   ├── backup.yml
│   ├── monitoring.yml
│   └── security_hardening.yml
│
└── backups/                       # Configuraciones respaldadas
```

---

## ⚙️ Instalación

### 1. Clonar el repositorio

```bash
git clone <repo-url>
cd ansible
```

### 2. Instalar dependencias

```bash
pip install ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Configurar credenciales con Vault

```bash
# Crear contraseña del vault
echo "mi_password_super_seguro" > .vault_pass
chmod 600 .vault_pass

# Cifrar el archivo de credenciales
ansible-vault encrypt group_vars/all/vault.yml

# Editar credenciales
ansible-vault edit group_vars/all/vault.yml
```

---

## 📦 Configuración de Inventario

Editar `inventories/lab/hosts.yml` con las IPs reales de tu VMware:

```yaml
cisco_ios:
  hosts:
    R1:
      ansible_host: 192.168.100.11   # ← Cambia esto
```

---

## 🔒 Uso de Vault (Credenciales)

```bash
# Cifrar archivo completo
ansible-vault encrypt group_vars/all/vault.yml

# Ver archivo cifrado
ansible-vault view group_vars/all/vault.yml

# Editar en caliente
ansible-vault edit group_vars/all/vault.yml

# Cifrar una sola variable
ansible-vault encrypt_string 'mi_password' --name 'vault_ansible_password'
```

---

## ▶️ Playbooks Disponibles

| Playbook                  | Descripción                          |
|---------------------------|--------------------------------------|
| `site.yml`                | Playbook maestro (todo en orden)     |
| `deploy_topology.yml`     | Despliegue completo desde cero       |
| `backup.yml`              | Backup de configuraciones            |
| `monitoring.yml`          | Validación y estado de la red        |
| `security_hardening.yml`  | Hardening de seguridad               |

---

## 🎭 Roles

| Rol                  | Qué hace                                          |
|----------------------|---------------------------------------------------|
| `common`             | Hostname, banner, NTP, DNS, logging               |
| `interfaces`         | Configurar IPs en interfaces                      |
| `routing`            | OSPF, BGP, EIGRP, RIP                             |
| `acl`                | Access Lists estándar y extendidas                |
| `security_hardening` | SSH v2, AAA, login block, servicios deshabilitados|
| `user_management`    | Crear/eliminar usuarios locales                   |
| `backup`             | show run con timestamp + restore                  |
| `monitoring`         | Validar interfaces, vecinos, rutas + reporte JSON |

---

## 🏷️ Tags Disponibles

```bash
# Ejecutar solo tareas específicas
ansible-playbook playbooks/site.yml --tags "common"
ansible-playbook playbooks/site.yml --tags "interfaces,routing"
ansible-playbook playbooks/site.yml --tags "backup"
ansible-playbook playbooks/site.yml --tags "monitoring"
ansible-playbook playbooks/site.yml --tags "hardening,ssh"

# Excluir tareas
ansible-playbook playbooks/site.yml --skip-tags "bgp"
```

---

## 💡 Ejemplos de Uso

```bash
# Desplegar topología completa
ansible-playbook playbooks/deploy_topology.yml

# Solo en R1 (modo dry-run)
ansible-playbook playbooks/site.yml --limit R1 --check

# Backup de todos los dispositivos
ansible-playbook playbooks/backup.yml

# Monitorear solo routers IOS
ansible-playbook playbooks/monitoring.yml --limit cisco_ios

# Hardening con verbose
ansible-playbook playbooks/security_hardening.yml -v

# Verificar inventario
ansible-inventory --list -i inventories/lab/hosts.yml

# Ping de conectividad
ansible all -m ping -i inventories/lab/hosts.yml
```

---

## 📝 Licencia

Proyecto de uso académico - Automatización de Redes.
