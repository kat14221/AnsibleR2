#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SCRIPT DE REFERENCIA — SWCORELIM1 OVS
# NOTA: La copia canónica está en roles/swcorelim1/files/
#       Este directorio scripts/ es solo referencia rápida.
# ============================================================

echo "[JHALEX] Configurando OVS SWCORELIM1..."

systemctl is-active --quiet openvswitch-switch || systemctl start openvswitch-switch

echo "[JHALEX] Limpiando estado OVS previo..."

ovs-vsctl --if-exists del-br br-core || true
ovs-vsctl --if-exists del-br br-core-cc || true
ovs-vsctl --if-exists del-br br-core-sd1 || true
ovs-vsctl --if-exists del-br br-core-sd2 || true

ovs-vsctl --if-exists del-port bond-pcsc1-sc2 || true
ovs-vsctl --if-exists del-port bond-psc1-sc2 || true   # typo cleanup
ovs-vsctl --if-exists del-port bond-pcsc1-sd1 || true
ovs-vsctl --if-exists del-port bond-pcsc1-sd2 || true  # eliminado en nueva topología
ovs-vsctl --if-exists del-port int-core-test || true

ip addr flush dev br-core 2>/dev/null || true
ip addr flush dev int-core-test 2>/dev/null || true
ip addr flush dev ens36 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true
ip addr flush dev ens38 2>/dev/null || true
ip addr flush dev ens39 2>/dev/null || true

ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens38 up || true
ip link set ens39 up || true

ovs-vsctl add-br br-core
ovs-vsctl set bridge br-core fail_mode=standalone
ovs-vsctl set bridge br-core rstp_enable=false

ovs-vsctl add-bond br-core bond-pcsc1-sc2 ens36 ens37
ovs-vsctl clear port bond-pcsc1-sc2 trunks || true
ovs-vsctl clear port bond-pcsc1-sc2 tag || true
ovs-vsctl clear port bond-pcsc1-sc2 vlan_mode || true
ovs-vsctl set port bond-pcsc1-sc2 bond_mode=active-backup
ovs-vsctl set port bond-pcsc1-sc2 lacp=off
ovs-vsctl set port bond-pcsc1-sc2 other_config:bond-primary=ens36

ovs-vsctl add-bond br-core bond-pcsc1-sd1 ens38 ens39
ovs-vsctl set port bond-pcsc1-sd1 bond_mode=active-backup
ovs-vsctl set port bond-pcsc1-sd1 lacp=off
ovs-vsctl set port bond-pcsc1-sd1 other_config:bond-primary=ens38
ovs-vsctl set port bond-pcsc1-sd1 trunks=10,20,30,40,50,60,70,80,99

ip link set br-core up || true
ip addr flush dev br-core || true
ip addr add 10.255.21.1/30 dev br-core

echo "[JHALEX] SWCORELIM1 - OVS configurado"
echo "[JHALEX] Topología: bond-pcsc1-sc2 (ens36+ens37, sin trunks) | bond-pcsc1-sd1 (ens38+ens39, trunk)"
echo "[JHALEX] bond-pcsc1-sd2 ELIMINADO (nueva topología)"
