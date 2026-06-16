#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SCRIPT DE REFERENCIA — SWDISTLIM1 OVS
# NOTA: La copia canónica está en roles/swdistlim1/files/
# ============================================================

echo "[JHALEX] Configurando OVS SWDISTLIM1..."

systemctl is-active --quiet openvswitch-switch || systemctl start openvswitch-switch

echo "[JHALEX] Limpiando estado OVS previo..."

# Limpiar bridges anteriores si existen
ovs-vsctl --if-exists del-br br-dist || true
ovs-vsctl --if-exists del-br br-core-cc || true
ovs-vsctl --if-exists del-br br-core-sd1 || true
ovs-vsctl --if-exists del-br br-core-sd2 || true

# Limpiar bonds/puertos huérfanos
ovs-vsctl --if-exists del-port int-core-test || true
ovs-vsctl --if-exists del-port bond-psc1-sc2 || true   # typo cleanup
ovs-vsctl --if-exists del-port bond-pcsc1-sd2 || true  # nunca debe existir en Dist1
ovs-vsctl --if-exists del-port bond-pcsc2-sd1 || true  # nunca debe existir en Dist1

# Limpiar IPs de interfaces OVS si existen
ip addr flush dev br-dist 2>/dev/null || true
ip addr flush dev ens34 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true
ip addr flush dev ens40 2>/dev/null || true
ip addr flush dev ens41 2>/dev/null || true
ip addr flush dev ens42 2>/dev/null || true
ip addr flush dev ens43 2>/dev/null || true
ip addr flush dev ens44 2>/dev/null || true
ip addr flush dev ens45 2>/dev/null || true

# Levantar interfaces físicas miembros
ip link set ens34 up || true
ip link set ens37 up || true
ip link set ens40 up || true
ip link set ens41 up || true
ip link set ens42 up || true
ip link set ens43 up || true
ip link set ens44 up || true
ip link set ens45 up || true

# Crear bridge principal con RSTP habilitado (protección contra bucles L2)
ovs-vsctl add-br br-dist
ovs-vsctl set bridge br-dist fail_mode=standalone
ovs-vsctl set bridge br-dist rstp_enable=true
# RSTP priority: Distribución1 es raíz preferida (prioridad más baja = más preferido)
# OVS usa other_config:rstp-priority si soportado; si no, rstp_enable=true es suficiente
ovs-vsctl set bridge br-dist other_config:rstp-priority=4096 || true

# --- Bond 1: SWDISTLIM1 ↔ SWCORELIM1 (PCSC1-SD1) ---
# Members: ens34 (primary), ens37
ovs-vsctl add-bond br-dist bond-pcsc1-sd1 ens34 ens37
ovs-vsctl set port bond-pcsc1-sd1 bond_mode=active-backup
ovs-vsctl set port bond-pcsc1-sd1 lacp=off
ovs-vsctl set port bond-pcsc1-sd1 other_config:bond-primary=ens34
ovs-vsctl set port bond-pcsc1-sd1 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 2: SWDISTLIM1 ↔ SWDISTLIM2 (PCSD1-SD2) ---
# Members: ens40 (primary), ens41
ovs-vsctl add-bond br-dist bond-pcsd1-sd2 ens40 ens41
ovs-vsctl set port bond-pcsd1-sd2 bond_mode=active-backup
ovs-vsctl set port bond-pcsd1-sd2 lacp=off
ovs-vsctl set port bond-pcsd1-sd2 other_config:bond-primary=ens40
ovs-vsctl set port bond-pcsd1-sd2 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 3: SWDISTLIM1 ↔ SWACCLIM1 (PCSD1-SA1) ---
# Members: ens42 (primary), ens43
ovs-vsctl add-bond br-dist bond-pcsd1-sa1 ens42 ens43
ovs-vsctl set port bond-pcsd1-sa1 bond_mode=active-backup
ovs-vsctl set port bond-pcsd1-sa1 lacp=off
ovs-vsctl set port bond-pcsd1-sa1 other_config:bond-primary=ens42
ovs-vsctl set port bond-pcsd1-sa1 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 4: SWDISTLIM1 ↔ SWACCLIM2 (PCSD1-SA2) ---
# Members: ens44 (primary), ens45
ovs-vsctl add-bond br-dist bond-pcsd1-sa2 ens44 ens45
ovs-vsctl set port bond-pcsd1-sa2 bond_mode=active-backup
ovs-vsctl set port bond-pcsd1-sa2 lacp=off
ovs-vsctl set port bond-pcsd1-sa2 other_config:bond-primary=ens44
ovs-vsctl set port bond-pcsd1-sa2 trunks=10,20,30,40,50,60,70,80,99

ip link set br-dist up || true

echo "[JHALEX] SWDISTLIM1 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-dist | RSTP: habilitado (prioridad raíz preferida)"
echo "[JHALEX] Bonds:"
echo "[JHALEX]   bond-pcsc1-sd1 (ens34+ens37) → Core1  | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsd1-sd2 (ens40+ens41) → Dist2  | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsd1-sa1 (ens42+ens43) → Acc1   | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsd1-sa2 (ens44+ens45) → Acc2   | trunk 10,20,30,40,50,60,70,80,99"
ovs-vsctl show
