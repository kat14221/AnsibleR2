#!/usr/bin/env bash
set -euo pipefail

echo "[JHALEX] Configurando OVS SWCORELIM2..."

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
ovs-vsctl --if-exists del-port bond-pcsc2-sd1 || true  # eliminado en nueva topología
ovs-vsctl --if-exists del-port bond-pcsc2-sd2 || true

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
# NOTA: ens38 y ens39 no existen en SWCORELIM2 (pertenecían al eliminado bond-pcsc2-sd1)
ip addr flush dev ens36 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true
ip addr flush dev ens40 2>/dev/null || true
ip addr flush dev ens41 2>/dev/null || true

# Levantar interfaces físicas miembros
ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens40 up || true
ip link set ens41 up || true

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

# --- Core2-Dist2 bond (trunk VLAN) ---
# Importante: ens41 es el enlace (1) — primario; ens40 es enlace (2) — backup
ovs-vsctl add-bond br-core bond-pcsc2-sd2 ens41 ens40
ovs-vsctl set port bond-pcsc2-sd2 bond_mode=active-backup
ovs-vsctl set port bond-pcsc2-sd2 lacp=off
ovs-vsctl set port bond-pcsc2-sd2 other_config:bond-primary=ens41
ovs-vsctl set port bond-pcsc2-sd2 trunks=10,20,30,40,50,60,70,80,99

ip link set br-core up || true
ip link set bond-pcsc1-sc2 up || true
ip link set bond-pcsc2-sd2 up || true

ip addr flush dev br-core || true
ip addr add 10.255.21.2/30 dev br-core

ip neigh flush dev br-core || true

echo "[JHALEX] SWCORELIM2 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-core | Bonds: bond-pcsc1-sc2 (ens36+ens37), bond-pcsc2-sd2 (ens41+ens40) | IP: 10.255.21.2/30"
echo "[JHALEX] Topología: Core2↔Core1 (sin trunks) | Core2↔Dist2 (trunk 10,20,30,40,50,60,70,80,99)"
echo "[JHALEX] bond-pcsc2-sd1 eliminado (nueva topología: SWCORELIM2 no conecta a SWDISTLIM1)"
