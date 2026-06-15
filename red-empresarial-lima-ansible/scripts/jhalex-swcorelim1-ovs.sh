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
ovs-vsctl --if-exists del-port bond-psc1-sc2 || true

# SWCORELIM1: limpiar bonds Core-Distribución antiguos
ovs-vsctl --if-exists del-port bond-pcsc1-sd1 || true
ovs-vsctl --if-exists del-port bond-pcsc1-sd2 || true

# Limpiar puerto interno antiguo del diseño anterior
ovs-vsctl --if-exists del-port int-core-test || true

# Limpiar IPs antiguas en interfaces OVS/lógicas si existen
ip addr flush dev br-core 2>/dev/null || true
ip addr flush dev br-core-cc 2>/dev/null || true
ip addr flush dev br-core-sd1 2>/dev/null || true
ip addr flush dev br-core-sd2 2>/dev/null || true
ip addr flush dev int-core-test 2>/dev/null || true

# Asegurar que las interfaces físicas miembros de OVS no tengan IP IPv4 previa
ip addr flush dev ens36 2>/dev/null || true
ip addr flush dev ens37 2>/dev/null || true
ip addr flush dev ens38 2>/dev/null || true
ip addr flush dev ens39 2>/dev/null || true
ip addr flush dev ens40 2>/dev/null || true
ip addr flush dev ens41 2>/dev/null || true

# Levantar interfaces físicas miembros
ip link set ens36 up || true
ip link set ens37 up || true
ip link set ens38 up || true
ip link set ens39 up || true
ip link set ens40 up || true
ip link set ens41 up || true

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

ovs-vsctl add-bond br-core bond-pcsc1-sd2 ens40 ens41
ovs-vsctl set port bond-pcsc1-sd2 bond_mode=active-backup
ovs-vsctl set port bond-pcsc1-sd2 lacp=off
ovs-vsctl set port bond-pcsc1-sd2 other_config:bond-primary=ens40
ovs-vsctl set port bond-pcsc1-sd2 trunks=10,20,30,40,50,60,70,80,99

ip link set br-core up || true
ip link set bond-pcsc1-sc2 up || true
ip link set bond-pcsc1-sd1 up || true
ip link set bond-pcsc1-sd2 up || true

ip addr flush dev br-core || true
ip addr add 10.255.21.1/30 dev br-core

ip neigh flush dev br-core || true

echo "[JHALEX] SWCORELIM1 - OVS configurado correctamente"
echo "[JHALEX] Bridge: br-core | Bonds: sc2, sd1, sd2 | IP: 10.255.21.1/30"
