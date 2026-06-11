#!/usr/bin/env bash
# =============================================================================
# bootstrap_swcorelim1.sh
# Script de inicialización de dependencias para SWCORELIM1
# =============================================================================
# Propósito: Instalar git, ansible, openvswitch y colecciones necesarias
#            antes de ejecutar el playbook por primera vez.
#
# Uso (ejecutar en la propia VM SWCORELIM1 como root):
#   chmod +x scripts/bootstrap_swcorelim1.sh
#   sudo bash scripts/bootstrap_swcorelim1.sh
#
# Después de este script, ejecutar:
#   cd /ruta/al/proyecto
#   ansible-playbook -i inventories/local/hosts.yml \
#     playbooks/02_configurar_swcorelim1.yml --ask-become-pass
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------
# Colores y helpers
# -----------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step()  { echo -e "${CYAN}[PASO]${NC}  $1"; }

# -----------------------------------------------------------------------
# Verificar que se ejecuta como root
# -----------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root: sudo bash $0"
fi

echo ""
echo "========================================================================"
echo "  Bootstrap SWCORELIM1 — Red Empresarial Lima (JHALEX)"
echo "  Switch Core Principal — Ubuntu Server 24.04 LTS"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================================"
echo ""

# -----------------------------------------------------------------------
# PASO 1: Detectar OS
# -----------------------------------------------------------------------
log_step "PASO 1: Detectando sistema operativo"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    log_ok "Sistema detectado: ${NAME} ${VERSION_ID:-''}"
else
    log_error "No se puede detectar el SO."
fi

if [[ "${ID}" != "ubuntu" ]]; then
    log_warn "SO no es Ubuntu. Este proyecto está diseñado para Ubuntu 24.04 LTS."
fi

if [[ "${VERSION_ID:-''}" != "24.04" ]]; then
    log_warn "Versión esperada: 24.04. Versión detectada: ${VERSION_ID:-'desconocida'}."
    log_warn "Continuar bajo su responsabilidad."
fi

# -----------------------------------------------------------------------
# PASO 2: Verificar conectividad (ens34 debe estar activa)
# -----------------------------------------------------------------------
log_step "PASO 2: Verificar conectividad de red"

if ip link show ens34 &>/dev/null; then
    log_ok "ens34 existe en el sistema."
    if ip -br addr show ens34 | grep -q "10.10.254."; then
        log_ok "ens34 tiene IP en la red 10.10.254.x (conectividad RLIM1 disponible)."
    else
        log_warn "ens34 no tiene IP 10.10.254.x aún. El bootstrap continúa pero Netplan debe configurarse."
    fi
else
    log_warn "ens34 no detectada. Verificar Port Group 'R1-S1' en VMware ESXi."
fi

# -----------------------------------------------------------------------
# PASO 3: Actualizar repositorios APT
# -----------------------------------------------------------------------
log_step "PASO 3: Actualizando repositorios APT"
apt-get update -qq
log_ok "Repositorios actualizados."

# -----------------------------------------------------------------------
# PASO 4: Instalar dependencias base
# -----------------------------------------------------------------------
log_step "PASO 4: Instalando dependencias base"
apt-get install -y -qq \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-apt \
    software-properties-common \
    gnupg \
    lsb-release \
    ca-certificates
log_ok "Dependencias base instaladas."

# -----------------------------------------------------------------------
# PASO 5: Instalar Open vSwitch (requerido para SWCORELIM1)
# -----------------------------------------------------------------------
log_step "PASO 5: Instalando Open vSwitch"

if command -v ovs-vsctl &>/dev/null; then
    log_warn "OVS ya instalado: $(ovs-vsctl --version | head -1)"
else
    apt-get install -y -qq openvswitch-switch
    log_ok "Open vSwitch instalado: $(ovs-vsctl --version | head -1)"
fi

systemctl enable openvswitch-switch
systemctl start openvswitch-switch
log_ok "openvswitch-switch activo y habilitado."

# -----------------------------------------------------------------------
# PASO 6: Instalar Ansible
# -----------------------------------------------------------------------
log_step "PASO 6: Instalando Ansible"

if command -v ansible &>/dev/null; then
    log_warn "Ansible ya instalado: $(ansible --version | head -1)"
else
    if [[ "${ID}" == "ubuntu" ]]; then
        add-apt-repository --yes --update ppa:ansible/ansible 2>/dev/null || true
        apt-get update -qq
        apt-get install -y -qq ansible
    else
        pip3 install --upgrade ansible
    fi

    if command -v ansible &>/dev/null; then
        log_ok "Ansible instalado: $(ansible --version | head -1)"
    else
        log_error "Fallo al instalar Ansible."
    fi
fi

# -----------------------------------------------------------------------
# PASO 7: Instalar lldpd
# -----------------------------------------------------------------------
log_step "PASO 7: Instalando lldpd"
apt-get install -y -qq lldpd
systemctl enable lldpd
systemctl start lldpd
log_ok "lldpd instalado y activo."

# -----------------------------------------------------------------------
# PASO 8: Instalar herramientas de red
# -----------------------------------------------------------------------
log_step "PASO 8: Instalando herramientas de red"
apt-get install -y -qq \
    iproute2 \
    iputils-ping \
    net-tools \
    traceroute \
    tcpdump \
    dnsutils \
    nftables \
    frr \
    frr-pythontools \
    keepalived \
    vim \
    htop
log_ok "Herramientas de red instaladas."

# FRR instalado pero NO habilitado
systemctl disable frr 2>/dev/null || true
systemctl stop frr 2>/dev/null || true
log_ok "FRR instalado pero NO habilitado (configurar más adelante)."

# Keepalived instalado pero NO habilitado
systemctl disable keepalived 2>/dev/null || true
systemctl stop keepalived 2>/dev/null || true
log_ok "Keepalived instalado pero NO habilitado (configurar más adelante)."

# -----------------------------------------------------------------------
# PASO 9: Instalar colecciones Ansible Galaxy
# -----------------------------------------------------------------------
log_step "PASO 9: Instalando colecciones Ansible Galaxy"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

if [[ -f "${REPO_DIR}/requirements.yml" ]]; then
    ansible-galaxy collection install -r "${REPO_DIR}/requirements.yml" --force-with-deps
    log_ok "Colecciones instaladas desde requirements.yml."
else
    log_warn "No se encontró requirements.yml. Instalando colecciones mínimas..."
    ansible-galaxy collection install ansible.posix community.general
    log_ok "Colecciones ansible.posix y community.general instaladas."
fi

# -----------------------------------------------------------------------
# PASO 10: Crear estructura de directorios
# -----------------------------------------------------------------------
log_step "PASO 10: Creando estructura de directorios"

mkdir -p /root/backups/swcorelim1/netplan
mkdir -p /root/backups/swcorelim1/ovs
mkdir -p /root/backups/swcorelim1/logs
chmod -R 700 /root/backups/swcorelim1

if [[ -d "${REPO_DIR}" ]]; then
    mkdir -p "${REPO_DIR}/logs"
    log_ok "Directorio de logs: ${REPO_DIR}/logs/"
fi

log_ok "Directorios de backup: /root/backups/swcorelim1/"

# -----------------------------------------------------------------------
# PASO 11: Verificar interfaces físicas
# -----------------------------------------------------------------------
log_step "PASO 11: Verificando interfaces físicas requeridas"

echo ""
echo "  Tabla de interfaces (ip -br link):"
ip -br link | head -20
echo ""

REQUIRED_IFACES=(ens34 ens35 ens36 ens37 ens38 ens39 ens40 ens41)
MISSING=0

for iface in "${REQUIRED_IFACES[@]}"; do
    if ip link show "$iface" &>/dev/null; then
        log_ok "  ${iface}: PRESENTE"
    else
        log_warn "  ${iface}: NO DETECTADA — Verificar Port Group en ESXi"
        MISSING=$((MISSING + 1))
    fi
done

if [[ $MISSING -gt 0 ]]; then
    log_warn "${MISSING} interfaces no detectadas. Verificar configuración de VM en ESXi."
    log_warn "El playbook validará las interfaces antes de aplicar cambios."
fi

# -----------------------------------------------------------------------
# Resumen final
# -----------------------------------------------------------------------
echo ""
echo "========================================================================"
echo "  Bootstrap SWCORELIM1 completado"
echo "========================================================================"
echo ""
log_ok "Git         : $(git --version)"
log_ok "Python3     : $(python3 --version)"
log_ok "Ansible     : $(ansible --version | head -1)"
log_ok "OVS         : $(ovs-vsctl --version | head -1)"
log_ok "lldpd       : $(systemctl is-active lldpd)"
echo ""
echo "  SIGUIENTE PASO:"
echo "  Ejecutar el playbook principal:"
echo ""
echo "  cd ${REPO_DIR}"
echo "  ansible-playbook -i inventories/local/hosts.yml \\"
echo "    playbooks/02_configurar_swcorelim1.yml --ask-become-pass"
echo ""
echo "  Para validar sin cambios (dry-run):"
echo "  ansible-playbook -i inventories/local/hosts.yml \\"
echo "    playbooks/02_configurar_swcorelim1.yml --check --diff --ask-become-pass"
echo ""
echo "  Para validar después de configurar:"
echo "  ansible-playbook -i inventories/local/hosts.yml \\"
echo "    playbooks/99_validar_swcorelim1.yml --ask-become-pass"
echo ""
echo "========================================================================"
