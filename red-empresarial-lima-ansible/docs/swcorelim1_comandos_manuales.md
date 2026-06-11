# =============================================================================
# SWCORELIM1 — Comandos Manuales, Validación y Rollback
# Proyecto JHALEX — Red Empresarial Lima
# =============================================================================
# Este archivo contiene todos los comandos equivalentes al playbook Ansible,
# para aplicarse manualmente directamente en SWCORELIM1 si no se usa Ansible.
#
# Sistema: Ubuntu Server 24.04 LTS
# Ejecución: Como root (sudo -i o sudo bash)
# =============================================================================

================================================================================
SECCIÓN 0 — DIAGNÓSTICO PREVIO (ejecutar siempre primero)
================================================================================

# Verificar hostname
hostname

# Tabla de interfaces (deben aparecer ens34..ens41)
ip -br link
ip -br addr
ip link show

# Si NO aparecen ens34..ens41: revisar Port Groups en VMware ESXi ANTES de continuar.

# Rutas actuales
ip route show

# Servicios activos
systemctl is-active ssh
systemctl is-active openvswitch-switch 2>/dev/null || echo "OVS no instalado"

================================================================================
SECCIÓN 1 — INSTALAR PAQUETES
================================================================================

# Actualizar APT
sudo apt-get update

# Instalar todos los paquetes requeridos
sudo apt-get install -y \
    openssh-server \
    openvswitch-switch \
    frr \
    frr-pythontools \
    keepalived \
    nftables \
    lldpd \
    tcpdump \
    traceroute \
    net-tools \
    curl \
    wget \
    vim \
    git \
    ansible

# Habilitar servicios activos
sudo systemctl enable --now ssh
sudo systemctl enable --now openvswitch-switch
sudo systemctl enable --now lldpd

# FRR y Keepalived: instalados pero NO habilitados
sudo systemctl disable frr 2>/dev/null || true
sudo systemctl stop frr 2>/dev/null || true
sudo systemctl disable keepalived 2>/dev/null || true
sudo systemctl stop keepalived 2>/dev/null || true

================================================================================
SECCIÓN 2 — HOSTNAME
================================================================================

# Configurar hostname
sudo hostnamectl set-hostname swcorelim1

# Verificar
hostname

# Actualizar /etc/hosts
sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1\tswcorelim1/' /etc/hosts

================================================================================
SECCIÓN 3 — BACKUP DE NETPLAN EXISTENTE
================================================================================

# Ver archivos actuales
ls -la /etc/netplan/

# Crear directorio de backup
sudo mkdir -p /root/backups/swcorelim1/netplan

# Hacer backup de todos los archivos Netplan actuales (ajustar nombre si difiere)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [ -f "$f" ] && sudo cp "$f" "/root/backups/swcorelim1/netplan/$(basename $f).bak.${TIMESTAMP}"
done

# Verificar backups
ls -la /root/backups/swcorelim1/netplan/

================================================================================
SECCIÓN 4 — CONFIGURAR NETPLAN
================================================================================

# Escribir el archivo Netplan canónico
sudo tee /etc/netplan/99-swcorelim1-netplan.yaml > /dev/null << 'EOF'
# =============================================================================
# /etc/netplan/99-swcorelim1-netplan.yaml
# SWCORELIM1 — Red Empresarial Lima (JHALEX)
# REGLAS: ens34 tiene ruta default. ens35 solo IP directa. ens36-41 sin IP (OVS).
# =============================================================================
network:
  version: 2
  ethernets:

    # ens34 — Enlace L3 hacia RLIM1-PRINCIPAL (RUTA DEFAULT AQUÍ)
    ens34:
      dhcp4: false
      addresses:
        - 10.10.254.2/30
      routes:
        - to: default
          via: 10.10.254.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 1.1.1.1

    # ens35 — Enlace L3 hacia RLIM2-SECUNDARIO (SIN gateway default)
    ens35:
      dhcp4: false
      addresses:
        - 10.10.254.10/30

    # ens36..ens41 — Miembros OVS (sin IP, administradas por OVS)
    ens36:
      dhcp4: false
    ens37:
      dhcp4: false
    ens38:
      dhcp4: false
    ens39:
      dhcp4: false
    ens40:
      dhcp4: false
    ens41:
      dhcp4: false
EOF

# Asegurar permisos correctos (Netplan requiere 600)
sudo chmod 600 /etc/netplan/99-swcorelim1-netplan.yaml

# Validar sintaxis ANTES de aplicar (no hace cambios)
sudo netplan generate
# Si no hay errores, continuar. Si hay errores, corregir el archivo.

# Aplicar solo si generate fue exitoso
sudo netplan apply

# Esperar estabilización
sleep 3

================================================================================
SECCIÓN 5 — VERIFICAR CONECTIVIDAD POST-NETPLAN
================================================================================

# Verificar IPs asignadas
ip -br addr

# Verificar ruta default (DEBE ser via 10.10.254.1)
ip route show

# Verificar que ens35 NO tiene ruta default
ip route show default

# --- PING CRÍTICO: Si falla, NO continuar con OVS ---
ping -c 4 10.10.254.1
# Si falla: verificar ens34, Netplan, estado de RLIM1.

# Pings informativos (pueden fallar, no son bloqueantes)
ping -c 4 10.10.254.9   # RLIM2 (puede bloquear ICMP)
ping -c 4 8.8.8.8       # Internet (depende de NAT en RLIM1)
ping -c 2 google.com    # DNS + Internet

# Si 10.10.254.1 responde pero 8.8.8.8 no: problema en RLIM1 (NAT Outbound / LINKR1S1)

================================================================================
SECCIÓN 6 — CONFIGURAR OPEN VSWITCH (idempotente)
================================================================================

# --- Paso 6.1: Crear bridge br-core (idempotente) ---
sudo ovs-vsctl br-exists br-core || sudo ovs-vsctl add-br br-core
sudo ovs-vsctl set bridge br-core rstp_enable=true
sudo ovs-vsctl set bridge br-core stp_enable=false

# Verificar
sudo ovs-vsctl show

# --- Paso 6.2: Bond Core-Core (ens36 + ens37 → SWCORELIM2) ---
# Verificar si ya existe
sudo ovs-vsctl list-ports br-core | grep bond-pcsc1-sc2 || \
    sudo ovs-vsctl add-bond br-core bond-pcsc1-sc2 ens36 ens37 bond_mode=balance-slb

# Confirmar modo (idempotente)
sudo ovs-vsctl set port bond-pcsc1-sc2 bond_mode=balance-slb

# --- Paso 6.3: Bond Core-Dist1 (ens38 + ens39 → SWDISTLIM1) ---
sudo ovs-vsctl list-ports br-core | grep bond-pcsc1-sd1 || \
    sudo ovs-vsctl add-bond br-core bond-pcsc1-sd1 ens38 ens39 bond_mode=balance-slb

sudo ovs-vsctl set port bond-pcsc1-sd1 bond_mode=balance-slb

# --- Paso 6.4: Bond Core-Dist2 (ens40 + ens41 → SWDISTLIM2) ---
sudo ovs-vsctl list-ports br-core | grep bond-pcsc1-sd2 || \
    sudo ovs-vsctl add-bond br-core bond-pcsc1-sd2 ens40 ens41 bond_mode=balance-slb

sudo ovs-vsctl set port bond-pcsc1-sd2 bond_mode=balance-slb

# --- Paso 6.5: Puerto interno int-core-test (10.255.21.1/30) ---
sudo ovs-vsctl list-ports br-core | grep int-core-test || \
    sudo ovs-vsctl add-port br-core int-core-test -- \
        set interface int-core-test type=internal

sudo ip addr replace 10.255.21.1/30 dev int-core-test 2>/dev/null || \
    sudo ip addr add 10.255.21.1/30 dev int-core-test 2>/dev/null || true
sudo ip link set int-core-test up

# --- Paso 6.6: Levantar interfaces físicas OVS ---
for iface in ens36 ens37 ens38 ens39 ens40 ens41; do
    ip link show "$iface" &>/dev/null && sudo ip link set "$iface" up
done

================================================================================
SECCIÓN 7 — INSTALAR SCRIPT Y SERVICIO SYSTEMD OVS
================================================================================

# Copiar el script OVS al sistema
sudo cp /ruta/al/proyecto/scripts/jhalex-swcorelim1-ovs.sh \
    /usr/local/sbin/jhalex-swcorelim1-ovs.sh
sudo chmod 750 /usr/local/sbin/jhalex-swcorelim1-ovs.sh

# Crear unidad systemd
sudo tee /etc/systemd/system/jhalex-swcorelim1-ovs.service > /dev/null << 'EOF'
[Unit]
Description=JHALEX SWCORELIM1 — Open vSwitch idempotent configuration
After=network.target openvswitch-switch.service
Requires=openvswitch-switch.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/jhalex-swcorelim1-ovs.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar el servicio
sudo systemctl daemon-reload
sudo systemctl enable jhalex-swcorelim1-ovs
sudo systemctl start jhalex-swcorelim1-ovs

# Verificar estado
sudo systemctl status jhalex-swcorelim1-ovs

================================================================================
SECCIÓN 8 — VALIDACIONES FINALES
================================================================================

echo "=== HOSTNAME ==="; hostname
echo "=== INTERFACES ==="; ip -br addr
echo "=== RUTAS ==="; ip route
echo "=== SSH ==="; systemctl is-active ssh
echo "=== OVS ==="; systemctl is-active openvswitch-switch
echo "=== LLDPD ==="; systemctl is-active lldpd
echo "=== OVS SHOW ==="; sudo ovs-vsctl show
echo "=== BONDS ==="; sudo ovs-appctl bond/show
echo "=== INT-CORE-TEST ==="; ip -br addr show int-core-test
echo "=== PING RLIM1 ==="; ping -c 4 10.10.254.1
echo "=== PING RLIM2 ==="; ping -c 4 10.10.254.9
echo "=== PING INTERNET ==="; ping -c 4 8.8.8.8
echo "=== PING DNS ==="; ping -c 2 google.com

================================================================================
TABLA DE RESULTADOS ESPERADOS
================================================================================

| Validación        | Resultado esperado                            | Estado |
|-------------------|-----------------------------------------------|--------|
| Hostname          | swcorelim1                                    | [ ]    |
| ens34             | 10.10.254.2/30 (UP)                           | [ ]    |
| ens35             | 10.10.254.10/30 (UP, sin gateway)             | [ ]    |
| Ruta default      | via 10.10.254.1 (ens34)                       | [ ]    |
| DNS               | 8.8.8.8, 1.1.1.1 en resolv.conf              | [ ]    |
| ssh               | active                                        | [ ]    |
| openvswitch-switch| active                                        | [ ]    |
| lldpd             | active                                        | [ ]    |
| br-core           | Bridge OVS existente con RSTP=true            | [ ]    |
| bond-pcsc1-sc2    | ens36 + ens37, balance-slb                    | [ ]    |
| bond-pcsc1-sd1    | ens38 + ens39, balance-slb                    | [ ]    |
| bond-pcsc1-sd2    | ens40 + ens41, balance-slb                    | [ ]    |
| int-core-test     | 10.255.21.1/30 (UP)                           | [ ]    |
| Ping RLIM1        | 10.10.254.1 responde (CRÍTICO)                | [ ]    |
| Ping RLIM2        | 10.10.254.9 (puede bloquear ICMP)             | [ ]    |
| Ping Internet     | 8.8.8.8 responde                              | [ ]    |
| DNS               | google.com resuelve                           | [ ]    |

================================================================================
PRUEBAS PENDIENTES (vecinos no configurados aún)
================================================================================

| Prueba                   | Requiere              | Estado     |
|--------------------------|-----------------------|------------|
| ping 10.255.21.2         | SWCORELIM2 configurado| PENDIENTE  |
| bond-pcsc1-sd1 activo    | SWDISTLIM1 configurado| PENDIENTE  |
| bond-pcsc1-sd2 activo    | SWDISTLIM2 configurado| PENDIENTE  |

================================================================================
SECCIÓN 9 — ROLLBACK COMPLETO
================================================================================

# ROLLBACK paso a paso. Ejecutar en orden.
# Solo si algo salió mal. NO ejecutar preventivamente.

# --- Paso R1: Deshabilitar y eliminar servicio systemd OVS ---
sudo systemctl disable --now jhalex-swcorelim1-ovs.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/jhalex-swcorelim1-ovs.service
sudo systemctl daemon-reload

# --- Paso R2: Eliminar script OVS ---
sudo rm -f /usr/local/sbin/jhalex-swcorelim1-ovs.sh

# --- Paso R3: Eliminar bridge OVS (SOLO si es necesario) ---
# ADVERTENCIA: Esto elimina toda la config OVS. Solo en caso extremo.
sudo ovs-vsctl --if-exists del-br br-core

# --- Paso R4: Restaurar Netplan desde backup ---
# Verificar qué backups existen
ls -la /root/backups/swcorelim1/netplan/

# Restaurar el backup más reciente (ajustar nombre del archivo):
BACKUP_FILE=$(ls -t /root/backups/swcorelim1/netplan/*.bak.* 2>/dev/null | head -1)
ORIGINAL_NAME=$(basename "$BACKUP_FILE" | sed 's/\.bak\..*//')

if [[ -n "$BACKUP_FILE" ]]; then
    echo "Restaurando: $BACKUP_FILE → /etc/netplan/$ORIGINAL_NAME"
    sudo cp "$BACKUP_FILE" "/etc/netplan/$ORIGINAL_NAME"
else
    echo "No hay backup disponible. Editar /etc/netplan manualmente."
fi

# Eliminar el archivo Netplan generado por el playbook
sudo rm -f /etc/netplan/99-swcorelim1-netplan.yaml

# --- Paso R5: Validar y aplicar Netplan restaurado ---
sudo netplan generate
# Solo si no hay errores:
sudo netplan apply

# Esperar estabilización
sleep 3

# --- Paso R6: Verificar que ens34 tiene conectividad ---
ip -br addr show ens34
ip route show default
ping -c 4 10.10.254.1

# --- Resumen post-rollback ---
echo "Rollback completado. Estado actual:"
hostname
ip -br addr
ip route show

================================================================================
COMANDOS DE DIAGNÓSTICO RÁPIDO (para uso diario)
================================================================================

# Estado completo de OVS en una línea
sudo ovs-vsctl show && sudo ovs-appctl bond/show

# Estado de todos los servicios relevantes
for svc in ssh openvswitch-switch lldpd jhalex-swcorelim1-ovs; do
    printf "%-35s %s\n" "$svc:" "$(systemctl is-active $svc 2>/dev/null || echo 'no instalado')"
done

# Ver logs del servicio OVS
sudo journalctl -u jhalex-swcorelim1-ovs --no-pager -n 50

# Vecinos LLDP detectados
sudo lldpctl

# Captura rápida en ens34 (5 paquetes)
sudo tcpdump -i ens34 -c 5 -n

# Verificar que RSTP está activo
sudo ovs-vsctl get bridge br-core rstp_enable

================================================================================
NOTAS IMPORTANTES
================================================================================

1. NUNCA ejecutar 'netplan apply' sin antes ejecutar 'netplan generate'.
2. NUNCA agregar gateway en ens35. La ruta default va solo por ens34.
3. NUNCA usar 'gateway4' en Netplan (deprecado en Ubuntu 24.04). Usar 'routes'.
4. NUNCA ejecutar 'ovs-vsctl del-br br-core' en producción salvo rollback explícito.
5. Si ping 10.10.254.1 falla: NO continuar con OVS. Resolver conectividad primero.
6. Si ping 8.8.8.8 falla pero 10.10.254.1 responde: problema en RLIM1 (NAT/LINKR1S1).
7. FRR, Keepalived y ACLs nftables: INSTALADOS pero no configurados. No tocar.
8. Los bonds (ens36-41) estarán en estado 'no partners' hasta configurar vecinos.
