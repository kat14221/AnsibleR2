#!/usr/bin/env bash
set -euo pipefail

echo "[JHALEX] Configurando OVS SWCORELIM2..."

systemctl is-active --quiet openvswitch-switch || systemctl start openvswitch-switch

ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens38 up || true
ip link set ens39 up || true
ip link set ens40 up || true
ip link set ens41 up || true

ovs-vsctl --if-exists del-br br-core

ovs-vsctl add-br br-core
ovs-vsctl set bridge br-core rstp_enable=true

ovs-vsctl add-bond br-core bond-pcsc1-sc2 ens36 ens37 bond_mode=active-backup lacp=off other_config:bond-primary=ens36
ovs-vsctl add-bond br-core bond-pcsc2-sd1 ens38 ens39 bond_mode=active-backup lacp=off other_config:bond-primary=ens38
ovs-vsctl add-bond br-core bond-pcsc2-sd2 ens40 ens41 bond_mode=active-backup lacp=off other_config:bond-primary=ens40

# Configurar trunks para enlaces hacia distribución
ovs-vsctl set port bond-pcsc2-sd1 trunks=10,20,30,40,50,60,70,80,99
ovs-vsctl set port bond-pcsc2-sd2 trunks=10,20,30,40,50,60,70,80,99

ip link set br-core up || true
ip link set bond-pcsc1-sc2 up || true
ip link set bond-pcsc2-sd1 up || true
ip link set bond-pcsc2-sd2 up || true

# Asignar IP al bridge br-core (enlace Core-Core)
ip addr flush dev br-core || true
ip addr add 10.255.21.2/30 dev br-core

echo "[JHALEX] SWCORELIM2 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-core | Bonds: sc2, sd1, sd2 | IP: 10.255.21.2/30"
