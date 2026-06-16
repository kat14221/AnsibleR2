# Guía de Ejecución — Switching Lima (JHALEX)
# Red Empresarial Lima — Ansible Automation
# ============================================================
#
# IMPORTANTE: Todos los comandos ansible-playbook DEBEN incluir:
#   -e @host_vars/<host>.yml   → carga variables específicas del switch
#   -K / --ask-become-pass     → contraseña para become (sudo)
#   -vv                        → verbosidad recomendada en producción
#
# El parámetro -K es obligatorio porque los roles ejecutan tareas con
# privilegios elevados mediante become.
# El parámetro -e @host_vars/<host>.yml se usa explícitamente para
# asegurar que las variables específicas del switch se carguen
# correctamente durante la ejecución.
# ============================================================

## 1. Preparación previa en cada VM

Antes de ejecutar los playbooks, verifica en cada VM:

```bash
# Verificar conectividad SSH
ssh ubuntu@<ip_vm>

# Verificar que Ansible está instalado
ansible --version

# Verificar que Open vSwitch está disponible
ovs-vsctl --version

# Verificar interfaces de red disponibles
ip -br link
```

---

## 2. Preparar el repositorio en cada VM

Ejecutar en la VM donde se va a correr el playbook localmente:

```bash
# Si el repo ya existe: actualizar
git -C ~/red-empresarial-lima-ansible pull --rebase

# Si hay cambios locales sin commit:
git -C ~/red-empresarial-lima-ansible stash
git -C ~/red-empresarial-lima-ansible pull --rebase
git -C ~/red-empresarial-lima-ansible stash pop

# Clonar si aún no existe:
git clone <URL_REPO> ~/red-empresarial-lima-ansible
cd ~/red-empresarial-lima-ansible
```

---

## 3. Convertir finales de línea y permisos

```bash
cd ~/red-empresarial-lima-ansible

# Convertir scripts OVS (si fueron editados en Windows)
dos2unix roles/swcorelim1/files/jhalex-swcorelim1-ovs.sh
dos2unix roles/swcorelim2/files/jhalex-swcorelim2-ovs.sh
dos2unix roles/swdistlim1/files/jhalex-swdistlim1-ovs.sh
dos2unix roles/swdistlim2/files/jhalex-swdistlim2-ovs.sh
dos2unix roles/swacclim1/files/jhalex-swacclim1-ovs.sh
dos2unix roles/swacclim2/files/jhalex-swacclim2-ovs.sh

# Asignar permisos de ejecución
chmod +x roles/swcorelim1/files/jhalex-swcorelim1-ovs.sh
chmod +x roles/swcorelim2/files/jhalex-swcorelim2-ovs.sh
chmod +x roles/swdistlim1/files/jhalex-swdistlim1-ovs.sh
chmod +x roles/swdistlim2/files/jhalex-swdistlim2-ovs.sh
chmod +x roles/swacclim1/files/jhalex-swacclim1-ovs.sh
chmod +x roles/swacclim2/files/jhalex-swacclim2-ovs.sh
```

---

## 4. Instalar colecciones Ansible requeridas

```bash
cd ~/red-empresarial-lima-ansible
ansible-galaxy collection install -r requirements.yml
```

---

## 5. Ejecución por fases

> **NOTA sobre become password:**
> El parámetro `-K` (`--ask-become-pass`) es obligatorio en todos los comandos
> porque los roles ejecutan tareas con `become: true` (equivalente a `sudo`).
> Se te pedirá la contraseña del usuario al inicio de cada ejecución.

> **NOTA sobre carga de variables:**
> El parámetro `-e @host_vars/<host>.yml` carga explícitamente las variables
> específicas del switch. Sin este parámetro, variables como `ovs_rstp_enabled`,
> `required_interfaces`, `ovs_bridge_name` y otras pueden no resolverse
> correctamente, causando errores difíciles de diagnosticar.

---

### Fase A — Core Switches

Ejecutar **en cada VM Core** (o desde controller con SSH configurado):

```bash
# ── SWCORELIM1 ──────────────────────────────────────────────────────────────

# Configuración completa
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swcorelim1.yml \
  -e @host_vars/swcorelim1.yml -vv -K

# Validación post-configuración
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swcorelim1.yml \
  -e @host_vars/swcorelim1.yml -vv -K

# ── SWCORELIM2 ──────────────────────────────────────────────────────────────

# Configuración completa
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swcorelim2.yml \
  -e @host_vars/swcorelim2.yml -vv -K

# Validación post-configuración
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swcorelim2.yml \
  -e @host_vars/swcorelim2.yml -vv -K
```

**Dry-run (sin cambios) antes de ejecutar:**
```bash
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swcorelim1.yml \
  -e @host_vars/swcorelim1.yml -vv -K --check --diff

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swcorelim2.yml \
  -e @host_vars/swcorelim2.yml -vv -K --check --diff
```

**Solo OVS (si ya está configurado el resto):**
```bash
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swcorelim1.yml \
  -e @host_vars/swcorelim1.yml -vv -K --tags ovs

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swcorelim2.yml \
  -e @host_vars/swcorelim2.yml -vv -K --tags ovs
```

---

### Fase B — Distribution Switches

> ⚠️ **Pre-requisito:** Ejecutar solo después de que Core switches estén
> operativos y los bonds Core-Core (bond-pcsc1-sc2) estén activos.
>
> RSTP **debe estar activo** (`rstp_enable=true`) en SWDISTLIM1 y SWDISTLIM2
> antes de activar los enlaces redundantes hacia Acceso. Los playbooks
> verifican esto automáticamente y fallan si RSTP no está configurado.

```bash
# ── SWDISTLIM1 ──────────────────────────────────────────────────────────────

# Configuración completa
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swdistlim1.yml \
  -e @host_vars/swdistlim1.yml -vv -K

# Validación post-configuración
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swdistlim1.yml \
  -e @host_vars/swdistlim1.yml -vv -K

# ── SWDISTLIM2 ──────────────────────────────────────────────────────────────

# Configuración completa
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swdistlim2.yml \
  -e @host_vars/swdistlim2.yml -vv -K

# Validación post-configuración
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swdistlim2.yml \
  -e @host_vars/swdistlim2.yml -vv -K
```

**Dry-run:**
```bash
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swdistlim1.yml \
  -e @host_vars/swdistlim1.yml -vv -K --check --diff

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swdistlim2.yml \
  -e @host_vars/swdistlim2.yml -vv -K --check --diff
```

**Solo OVS:**
```bash
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swdistlim1.yml \
  -e @host_vars/swdistlim1.yml -vv -K --tags ovs

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swdistlim2.yml \
  -e @host_vars/swdistlim2.yml -vv -K --tags ovs
```

---

### Fase C — Access Switches

> ⚠️ **Pre-requisito:** Ejecutar solo después de que Distribution switches
> estén operativos y RSTP activo en br-dist.
>
> RSTP **debe estar activo** (`rstp_enable=true`) en SWACCLIM1 y SWACCLIM2.
> La redundancia Distribución–Acceso depende de:
>   1. Bonds OVS en `active-backup` (redundancia dentro de cada port-channel).
>   2. RSTP activo en `br-dist` y `br-acc` (previene bucles entre caminos redundantes).
>
> **No existe balanceo de ancho de banda ni LACP.** Es redundancia de failover.

```bash
# ── SWACCLIM1 ──────────────────────────────────────────────────────────────

# Configuración completa
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swacclim1.yml \
  -e @host_vars/swacclim1.yml -vv -K

# Validación post-configuración
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swacclim1.yml \
  -e @host_vars/swacclim1.yml -vv -K

# ── SWACCLIM2 ──────────────────────────────────────────────────────────────

# Configuración completa
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swacclim2.yml \
  -e @host_vars/swacclim2.yml -vv -K

# Validación post-configuración
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/99_validar_swacclim2.yml \
  -e @host_vars/swacclim2.yml -vv -K
```

**Dry-run:**
```bash
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swacclim1.yml \
  -e @host_vars/swacclim1.yml -vv -K --check --diff

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swacclim2.yml \
  -e @host_vars/swacclim2.yml -vv -K --check --diff
```

**Solo OVS:**
```bash
ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swacclim1.yml \
  -e @host_vars/swacclim1.yml -vv -K --tags ovs

ansible-playbook -i inventories/local/hosts.yml \
  playbooks/02_configurar_swacclim2.yml \
  -e @host_vars/swacclim2.yml -vv -K --tags ovs
```

---

## 6. Validación manual por switch

Comandos para verificar manualmente el estado OVS en cada VM:

### SWCORELIM1 y SWCORELIM2 (bridge: br-core)

```bash
# Ver estado completo OVS
sudo ovs-vsctl show

# Verificar RSTP (Core usa false — L3, no necesita STP)
sudo ovs-vsctl get bridge br-core rstp_enable

# Ver bonds y miembro activo
sudo ovs-appctl bond/show

# Verificar IP del bridge
ip addr show br-core

# Verificar que bond-pcsc1-sc2 está arriba
ip -br link show bond-pcsc1-sc2

# Verificar conectividad Core-Core
ping 10.255.21.2  # desde SWCORELIM1 hacia SWCORELIM2
ping 10.255.21.1  # desde SWCORELIM2 hacia SWCORELIM1
```

### SWDISTLIM1 (bridge: br-dist)

```bash
# Estado OVS completo
sudo ovs-vsctl show

# ✅ OBLIGATORIO: Verificar RSTP activo
sudo ovs-vsctl get bridge br-dist rstp_enable
# Esperado: true

# Verificar prioridad RSTP (raíz preferida)
sudo ovs-vsctl get bridge br-dist other_config
# Esperado: contiene rstp-priority=4096

# Ver todos los bonds
sudo ovs-appctl bond/show

# Verificar puertos del bridge
sudo ovs-vsctl list-ports br-dist

# Estado RSTP detallado
sudo ovs-appctl rstp/show
```

### SWDISTLIM2 (bridge: br-dist)

```bash
sudo ovs-vsctl show

# ✅ OBLIGATORIO: Verificar RSTP activo
sudo ovs-vsctl get bridge br-dist rstp_enable
# Esperado: true

# Verificar prioridad RSTP (raíz secundaria)
sudo ovs-vsctl get bridge br-dist other_config
# Esperado: contiene rstp-priority=8192

sudo ovs-appctl bond/show
sudo ovs-vsctl list-ports br-dist

# Verificar que bond-pcsc2-sd1 NO existe
sudo ovs-vsctl list-ports br-dist | grep -c bond-pcsc2-sd1 || echo "OK: no existe"
```

### SWACCLIM1 y SWACCLIM2 (bridge: br-acc)

```bash
sudo ovs-vsctl show

# ✅ OBLIGATORIO: Verificar RSTP activo (nunca root)
sudo ovs-vsctl get bridge br-acc rstp_enable
# Esperado: true

# Verificar prioridad RSTP (nunca root bridge)
sudo ovs-vsctl get bridge br-acc other_config
# Esperado: contiene rstp-priority=28672

sudo ovs-appctl bond/show
sudo ovs-vsctl list-ports br-acc
sudo ovs-appctl rstp/show
```

---

## 7. Tabla de estado RSTP esperado

| Switch     | Bridge   | RSTP       | Priority | Rol RSTP            |
|------------|----------|------------|----------|---------------------|
| SWCORELIM1 | br-core  | **false**  | —        | L3 — no participa   |
| SWCORELIM2 | br-core  | **false**  | —        | L3 — no participa   |
| SWDISTLIM1 | br-dist  | **true** ✅ | 4096     | Root bridge preferido |
| SWDISTLIM2 | br-dist  | **true** ✅ | 8192     | Root bridge secundario |
| SWACCLIM1  | br-acc   | **true** ✅ | 28672    | Nunca root          |
| SWACCLIM2  | br-acc   | **true** ✅ | 28672    | Nunca root          |

> **ADVERTENCIA:** Si `rstp_enable` devuelve `false` en Distribución o Acceso,
> **NO continuar** activando enlaces redundantes. Existe riesgo de bucle L2.
> Ejecutar el playbook de configuración con `--tags ovs` para re-aplicar.

---

## 8. Notas operativas

### become password (`-K`)
- Requerido en **todos** los playbooks porque usan `become: true`.
- Equivalente a ejecutar tareas como `root` vía `sudo`.
- Si se automatiza desde un controller, usar `ansible_become_password` en
  vault cifrado (nunca en texto plano).

### Carga explícita de variables (`-e @host_vars/<host>.yml`)
- Requerido porque la ejecución es **local** (`ansible_connection: local`).
- Sin este parámetro, variables como `ovs_rstp_enabled`, `required_interfaces`,
  `ovs_bridge_name`, `trunk_vlans` y otras no se resuelven correctamente.
- Causa errores de tipo `variable is undefined` difíciles de diagnosticar.

### Redundancia Distribución–Acceso
La alta disponibilidad en la capa Distribución–Acceso funciona así:

1. **Bonds OVS `active-backup`** → redundancia de failover dentro de cada
   port-channel (un enlace físico falla, el otro toma el tráfico).
2. **RSTP activo en `br-dist` y `br-acc`** → previene bucles L2 entre los
   caminos redundantes. Sin RSTP, si ambos uplinks de Acceso están activos
   a diferentes switches Distribución, se forma un bucle de broadcast.

No existe LACP, no existe balanceo de ancho de banda entre los bonds.

### Interfaces futuras para VMs de Acceso
Las interfaces `ens38+` en SWACCLIM1 y SWACCLIM2 están reservadas para
la próxima fase de configuración de acceso para VMs finales.
**No tocarlas** en esta fase.
