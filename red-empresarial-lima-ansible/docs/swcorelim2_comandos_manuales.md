# =============================================================================
# SWCORELIM2 — Comandos Manuales, Validación y Rollback
# Proyecto JHALEX — Red Empresarial Lima
# =============================================================================

## Diagnóstico previo

hostname
ip -br link
ip -br addr
ip route show

## Netplan

sudo mkdir -p /root/backups/swcorelim2/netplan
sudo netplan generate
sudo netplan apply

## OVS

sudo ovs-vsctl add-br br-core
sudo ovs-vsctl set bridge br-core rstp_enable=true
sudo ovs-vsctl add-bond br-core bond-pcsc1-sc2 ens36 ens37 bond_mode=balance-slb
sudo ovs-vsctl add-bond br-core bond-pcsc2-sd1 ens38 ens39 bond_mode=balance-slb
sudo ovs-vsctl add-bond br-core bond-pcsc2-sd2 ens40 ens41 bond_mode=balance-slb
sudo ovs-vsctl add-port br-core int-core-test -- set interface int-core-test type=internal
sudo ip addr replace 10.255.21.2/30 dev int-core-test
sudo ip link set int-core-test up

## Servicio systemd

sudo cp scripts/jhalex-swcorelim2-ovs.sh /usr/local/sbin/jhalex-swcorelim2-ovs.sh
sudo chmod 750 /usr/local/sbin/jhalex-swcorelim2-ovs.sh
sudo cp roles/swcorelim2/templates/jhalex-swcorelim2-ovs.service.j2 /etc/systemd/system/jhalex-swcorelim2-ovs.service
sudo systemctl daemon-reload
sudo systemctl enable jhalex-swcorelim2-ovs
sudo systemctl start jhalex-swcorelim2-ovs

## Validaciones

hostname
ip -br addr
ip route show default
systemctl is-active openvswitch-switch
systemctl is-active lldpd
systemctl is-enabled jhalex-swcorelim2-ovs
ovs-vsctl show
ovs-appctl bond/show