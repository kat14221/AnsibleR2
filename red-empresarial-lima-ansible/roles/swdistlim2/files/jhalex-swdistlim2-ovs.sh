#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SCRIPT DE REFERENCIA — SWDISTLIM2 OVS
# NOTA: La copia canónica está en roles/swdistlim2/files/
# ============================================================

echo "[JHALEX] Configurando OVS SWDISTLIM2..."

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
ovs-vsctl --if-exists del-port bond-pcsc1-sd2 || true  # nunca debe existir en Dist2
ovs-vsctl --if-exists del-port bond-pcsc2-sd1 || true  # nunca debe existir en Dist2

# Limpiar IPs de interfaces OVS si existen
ip addr flush dev br-dist 2>/dev/null || true
ip addr flush dev ens36 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true
ip addr flush dev ens38 2>/dev/null || true
ip addr flush dev ens39 2>/dev/null || true
ip addr flush dev ens40 2>/dev/null || true
ip addr flush dev ens41 2>/dev/null || true
ip addr flush dev ens42 2>/dev/null || true
ip addr flush dev ens43 2>/dev/null || true

# Levantar interfaces físicas miembros
ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens38 up || true
ip link set ens39 up || true
ip link set ens40 up || true
ip link set ens41 up || true
ip link set ens42 up || true
ip link set ens43 up || true

# Crear bridge principal con RSTP habilitado (protección contra bucles L2)
ovs-vsctl add-br br-dist
ovs-vsctl set bridge br-dist fail_mode=standalone
ovs-vsctl set bridge br-dist rstp_enable=true
# RSTP priority: Distribución2 es raíz secundaria (prioridad más alta que Dist1)
ovs-vsctl set bridge br-dist other_config:rstp-priority=8192 || true

# --- Bond 1: SWDISTLIM2 ↔ SWCORELIM2 (PCSC2-SD2) ---
# Members: ens36 (primary), ens37
ovs-vsctl add-bond br-dist bond-pcsc2-sd2 ens36 ens37
ovs-vsctl set port bond-pcsc2-sd2 bond_mode=active-backup
ovs-vsctl set port bond-pcsc2-sd2 lacp=off
ovs-vsctl set port bond-pcsc2-sd2 other_config:bond-primary=ens36
ovs-vsctl set port bond-pcsc2-sd2 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 2: SWDISTLIM2 ↔ SWDISTLIM1 (PCSD1-SD2) ---
# Members: ens38 (primary), ens39
ovs-vsctl add-bond br-dist bond-pcsd1-sd2 ens38 ens39
ovs-vsctl set port bond-pcsd1-sd2 bond_mode=active-backup
ovs-vsctl set port bond-pcsd1-sd2 lacp=off
ovs-vsctl set port bond-pcsd1-sd2 other_config:bond-primary=ens38
ovs-vsctl set port bond-pcsd1-sd2 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 3: SWDISTLIM2 ↔ SWACCLIM1 (PCSA1-SD2) ---
# Members: ens40 (primary), ens41
# NOTA: El Port Group real se llama PCSA1-SD2 en ESXi
ovs-vsctl add-bond br-dist bond-pcsa1-sd2 ens40 ens41
ovs-vsctl set port bond-pcsa1-sd2 bond_mode=active-backup
ovs-vsctl set port bond-pcsa1-sd2 lacp=off
ovs-vsctl set port bond-pcsa1-sd2 other_config:bond-primary=ens40
ovs-vsctl set port bond-pcsa1-sd2 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 4: SWDISTLIM2 ↔ SWACCLIM2 (PCSD2-SA2) ---
# Members: ens42 (primary), ens43
ovs-vsctl add-bond br-dist bond-pcsd2-sa2 ens42 ens43
ovs-vsctl set port bond-pcsd2-sa2 bond_mode=active-backup
ovs-vsctl set port bond-pcsd2-sa2 lacp=off
ovs-vsctl set port bond-pcsd2-sa2 other_config:bond-primary=ens42
ovs-vsctl set port bond-pcsd2-sa2 trunks=10,20,30,40,50,60,70,80,99

ip link set br-dist up || true

echo "[JHALEX] SWDISTLIM2 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-dist | RSTP: habilitado (prioridad raíz secundaria)"
echo "[JHALEX] Bonds:"
echo "[JHALEX]   bond-pcsc2-sd2 (ens36+ens37) → Core2  | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsd1-sd2 (ens38+ens39) → Dist1  | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsa1-sd2 (ens40+ens41) → Acc1   | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsd2-sa2 (ens42+ens43) → Acc2   | trunk 10,20,30,40,50,60,70,80,99"
ovs-vsctl show
