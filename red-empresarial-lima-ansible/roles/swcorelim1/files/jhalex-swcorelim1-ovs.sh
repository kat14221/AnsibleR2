#!/usr/bin/env bash
set -euo pipefail

echo "[JHALEX] Configurando OVS SWCORELIM1..."

systemctl is-active --quiet openvswitch-switch || systemctl start openvswitch-switch

echo "[JHALEX] Limpiando estado OVS previo..."

# Limpiar bridges antiguos usados en pruebas previas
ovs-vsctl --if-exists del-br br-core || true
ovs-vsctl --if-exists del-br br-core-cc || true
ovs-vsctl --if-exists del-br br-core-sd1 || true
ovs-vsctl --if-exists del-br br-core-sd2 || true

# Limpiar puertos/bonds antiguos por si quedaron sueltos en la base OVS
ovs-vsctl --if-exists del-port bond-pcsc1-sc2 || true
ovs-vsctl --if-exists del-port bond-psc1-sc2 || true   # typo cleanup
ovs-vsctl --if-exists del-port bond-pcsc1-sd1 || true
ovs-vsctl --if-exists del-port bond-pcsc1-sd2 || true  # eliminado en nueva topología

# Limpiar puerto interno antiguo del diseño anterior
ovs-vsctl --if-exists del-port int-core-test || true

# Limpiar IPs antiguas en interfaces OVS/lógicas si existen
ip addr flush dev br-core 2>/dev/null || true
ip addr flush dev br-core-cc 2>/dev/null || true
ip addr flush dev br-core-sd1 2>/dev/null || true
ip addr flush dev br-core-sd2 2>/dev/null || true
ip addr flush dev int-core-test 2>/dev/null || true

# Asegurar que las interfaces físicas miembros de OVS no tengan IP IPv4 previa
# NOTA: ens34 y ens35 son de Netplan (L3 hacia firewalls) — NO tocar
ip addr flush dev ens36 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true
ip addr flush dev ens38 2>/dev/null || true
ip addr flush dev ens39 2>/dev/null || true

# Levantar interfaces físicas miembros
ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens38 up || true
ip link set ens39 up || true

ovs-vsctl add-br br-core
ovs-vsctl set bridge br-core fail_mode=standalone
ovs-vsctl set bridge br-core rstp_enable=false

# --- Core-Core bond (sin trunks, sin tag, sin vlan_mode — solo IP en br-core) ---
ovs-vsctl add-bond br-core bond-pcsc1-sc2 ens36 ens37
ovs-vsctl clear port bond-pcsc1-sc2 trunks || true
ovs-vsctl clear port bond-pcsc1-sc2 tag || true
ovs-vsctl clear port bond-pcsc1-sc2 vlan_mode || true
ovs-vsctl set port bond-pcsc1-sc2 bond_mode=active-backup
ovs-vsctl set port bond-pcsc1-sc2 lacp=off
ovs-vsctl set port bond-pcsc1-sc2 other_config:bond-primary=ens36

# --- Core1-Dist1 bond (trunk VLAN) ---
ovs-vsctl add-bond br-core bond-pcsc1-sd1 ens38 ens39
ovs-vsctl set port bond-pcsc1-sd1 bond_mode=active-backup
ovs-vsctl set port bond-pcsc1-sd1 lacp=off
ovs-vsctl set port bond-pcsc1-sd1 other_config:bond-primary=ens38
ovs-vsctl set port bond-pcsc1-sd1 trunks=10,20,30,40,50,60,70,80,99

ip link set br-core up || true
ip link set bond-pcsc1-sc2 up || true
ip link set bond-pcsc1-sd1 up || true

ip addr flush dev br-core || true
ip addr add 10.255.21.1/30 dev br-core

ip neigh flush dev br-core || true

echo "[JHALEX] SWCORELIM1 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-core | Bonds: bond-pcsc1-sc2 (ens36+ens37), bond-pcsc1-sd1 (ens38+ens39) | IP: 10.255.21.1/30"
echo "[JHALEX] Topología: Core1↔Core2 (sin trunks) | Core1↔Dist1 (trunk 10,20,30,40,50,60,70,80,99)"
echo "[JHALEX] bond-pcsc1-sd2 eliminado (nueva topología: SWCORELIM1 no conecta a SWDISTLIM2)"
