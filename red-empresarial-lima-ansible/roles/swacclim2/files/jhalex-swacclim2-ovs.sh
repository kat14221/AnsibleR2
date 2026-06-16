#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SCRIPT DE REFERENCIA — SWACCLIM2 OVS
# NOTA: La copia canónica está en roles/swacclim2/files/
# ============================================================

echo "[JHALEX] Configurando OVS SWACCLIM2..."

systemctl is-active --quiet openvswitch-switch || systemctl start openvswitch-switch

echo "[JHALEX] Limpiando estado OVS previo..."

# Limpiar bridges anteriores si existen
ovs-vsctl --if-exists del-br br-acc || true
ovs-vsctl --if-exists del-br br-core-cc || true
ovs-vsctl --if-exists del-br br-core-sd1 || true
ovs-vsctl --if-exists del-br br-core-sd2 || true

# Limpiar bonds/puertos huérfanos
ovs-vsctl --if-exists del-port int-core-test || true
ovs-vsctl --if-exists del-port bond-psc1-sc2 || true   # typo cleanup
ovs-vsctl --if-exists del-port bond-pcsc1-sd2 || true  # nunca debe existir en Acc
ovs-vsctl --if-exists del-port bond-pcsc2-sd1 || true  # nunca debe existir en Acc

# Limpiar IPs de interfaces OVS si existen
# NOTA: Solo limpiar ens34-ens37 (interfaces de uplink a Distribución)
# NO tocar interfaces futuras de VMs de acceso (ens38+)
ip addr flush dev br-acc 2>/dev/null || true
ip addr flush dev ens34 2>/dev/null || true
ip addr flush dev ens35 2>/dev/null || true
ip addr flush dev ens36 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true

# Levantar interfaces físicas de uplink
ip link set ens34 up || true
ip link set ens35 up || true
ip link set ens36 up || true
ip link set ens37 up || true

# Crear bridge principal con RSTP habilitado (Acceso nunca debe ser root)
ovs-vsctl add-br br-acc
ovs-vsctl set bridge br-acc fail_mode=standalone
ovs-vsctl set bridge br-acc rstp_enable=true
# RSTP priority: Acceso tiene prioridad alta (nunca será root bridge)
ovs-vsctl set bridge br-acc other_config:rstp-priority=28672 || true

# --- Bond 1: SWACCLIM2 ↔ SWDISTLIM1 (PCSD1-SA2) ---
# Members: ens34 (primary), ens35
ovs-vsctl add-bond br-acc bond-pcsd1-sa2 ens34 ens35
ovs-vsctl set port bond-pcsd1-sa2 bond_mode=active-backup
ovs-vsctl set port bond-pcsd1-sa2 lacp=off
ovs-vsctl set port bond-pcsd1-sa2 other_config:bond-primary=ens34
ovs-vsctl set port bond-pcsd1-sa2 trunks=10,20,30,40,50,60,70,80,99

# --- Bond 2: SWACCLIM2 ↔ SWDISTLIM2 (PCSD2-SA2) ---
# Members: ens36 (primary), ens37
ovs-vsctl add-bond br-acc bond-pcsd2-sa2 ens36 ens37
ovs-vsctl set port bond-pcsd2-sa2 bond_mode=active-backup
ovs-vsctl set port bond-pcsd2-sa2 lacp=off
ovs-vsctl set port bond-pcsd2-sa2 other_config:bond-primary=ens36
ovs-vsctl set port bond-pcsd2-sa2 trunks=10,20,30,40,50,60,70,80,99

ip link set br-acc up || true

echo "[JHALEX] SWACCLIM2 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-acc | RSTP: habilitado (nunca root)"
echo "[JHALEX] Bonds:"
echo "[JHALEX]   bond-pcsd1-sa2 (ens34+ens35) → Dist1 | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX]   bond-pcsd2-sa2 (ens36+ens37) → Dist2 | trunk 10,20,30,40,50,60,70,80,99"
echo "[JHALEX] NOTA: Interfaces futuras para VMs de acceso (ens38+) NO tocar en esta fase."
ovs-vsctl show
