#!/usr/bin/env bash
set -euo pipefail

echo "[JHALEX] Configurando OVS SWCORELIM1..."

systemctl is-active --quiet openvswitch-switch || systemctl start openvswitch-switch

ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens38 up || true
ip link set ens39 up || true
ip link set ens40 up || true
ip link set ens41 up || true

ovs-vsctl --if-exists del-br br-core

ovs-vsctl add-br br-core
ovs-vsctl set Bridge br-core rstp_enable=true

ovs-vsctl add-bond br-core bond-pcsc1-sc2 ens36 ens37 bond_mode=active-backup lacp=off other_config:bond-primary=ens36
ovs-vsctl add-bond br-core bond-pcsc1-sd1 ens38 ens39 bond_mode=balance-slb lacp=off
ovs-vsctl add-bond br-core bond-pcsc1-sd2 ens40 ens41 bond_mode=balance-slb lacp=off

ovs-vsctl add-port br-core int-core-test -- set Interface int-core-test type=internal
ovs-vsctl set port int-core-test tag=99

ip link set br-core up || true
ip link set bond-pcsc1-sc2 up || true
ip link set bond-pcsc1-sd1 up || true
ip link set bond-pcsc1-sd2 up || true
ip link set int-core-test up || true

ip addr flush dev int-core-test || true
ip addr add 10.255.21.1/30 dev int-core-test

echo "[JHALEX] SWCORELIM1 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-core | Bonds: sc2, sd1, sd2 | Internal: int-core-test 10.255.21.1/30"
