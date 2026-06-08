#!/usr/bin/env bash
# =============================================================================
# bootstrap_rlimengano.sh
# Script de inicialización de dependencias para RLIMENGANO
# =============================================================================
# Propósito: Instalar git, ansible y colecciones necesarias antes de ejecutar
#            el playbook por primera vez.
#
# Uso:
#   chmod +x scripts/bootstrap_rlimengano.sh
#   sudo bash scripts/bootstrap_rlimengano.sh
#
# Después de ejecutar este script, se puede correr:
#   ansible-playbook -i inventories/local/hosts.yml \
#     playbooks/01_configurar_rlimengano.yml --ask-become-pass
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------
# Colores y helpers para output
# -----------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# -----------------------------------------------------------------------
# Verificar que se ejecuta como root
# -----------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root (sudo bash bootstrap_rlimengano.sh)"
fi

echo ""
echo "========================================================"
echo "  Bootstrap RLIMENGANO - Red Empresarial Lima"
echo "  ISP Secundario Simulado"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# Paso 1: Detectar el sistema operativo
# -----------------------------------------------------------------------
log_info "Detectando sistema operativo..."

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    log_ok "Sistema detectado: ${NAME} ${VERSION_ID:-''}"
else
    log_error "No se puede detectar el SO. Este script requiere Ubuntu/Debian."
fi

if [[ "${ID}" != "ubuntu" && "${ID}" != "debian" ]]; then
    log_warn "SO no reconocido como Ubuntu/Debian. Continuando de todas formas..."
fi

# -----------------------------------------------------------------------
# Paso 2: Actualizar repositorios APT
# -----------------------------------------------------------------------
log_info "Actualizando lista de repositorios APT..."
apt-get update -qq
log_ok "Repositorios APT actualizados."

# -----------------------------------------------------------------------
# Paso 3: Instalar dependencias base
# -----------------------------------------------------------------------
log_info "Instalando dependencias base: git, curl, python3, pip..."
apt-get install -y -qq \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-apt \
    software-properties-common \
    gnupg \
    lsb-release
log_ok "Dependencias base instaladas."

# -----------------------------------------------------------------------
# Paso 4: Instalar Ansible desde PPA oficial de Ansible
# -----------------------------------------------------------------------
log_info "Instalando Ansible..."

# Verificar si ansible ya está instalado
if command -v ansible &>/dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -1)
    log_warn "Ansible ya está instalado: ${ANSIBLE_VERSION}"
    log_info "Si necesitas una versión más reciente, usa: pip3 install --upgrade ansible"
else
    # Intentar instalar desde el repositorio oficial de Ansible
    log_info "Agregando repositorio oficial de Ansible (PPA)..."
    
    # Añadir repositorio PPA de Ansible para Ubuntu
    if [[ "${ID}" == "ubuntu" ]]; then
        add-apt-repository --yes --update ppa:ansible/ansible 2>/dev/null || true
        apt-get update -qq
        apt-get install -y -qq ansible
    else
        # Para Debian o sistemas no-Ubuntu, usar pip
        log_info "Instalando Ansible via pip3..."
        pip3 install --upgrade ansible
    fi
    
    if command -v ansible &>/dev/null; then
        log_ok "Ansible instalado: $(ansible --version | head -1)"
    else
        log_error "Fallo al instalar Ansible. Revisar los logs anteriores."
    fi
fi

# -----------------------------------------------------------------------
# Paso 5: Verificar versión mínima de Ansible
# -----------------------------------------------------------------------
log_info "Verificando versión de Ansible..."
ANSIBLE_VERSION_NUM=$(ansible --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
log_ok "Ansible versión: ${ANSIBLE_VERSION_NUM}"

# -----------------------------------------------------------------------
# Paso 6: Instalar colecciones de Ansible Galaxy
# -----------------------------------------------------------------------
log_info "Instalando colecciones de Ansible Galaxy..."

# Directorio del repositorio (donde está este script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

if [[ -f "${REPO_DIR}/requirements.yml" ]]; then
    log_info "Instalando colecciones desde requirements.yml..."
    ansible-galaxy collection install -r "${REPO_DIR}/requirements.yml" --force-with-deps
    log_ok "Colecciones instaladas."
else
    log_warn "No se encontró requirements.yml en ${REPO_DIR}/"
    log_info "Instalando colecciones manualmente..."
    ansible-galaxy collection install ansible.posix community.general
    log_ok "Colecciones ansible.posix y community.general instaladas."
fi

# -----------------------------------------------------------------------
# Paso 7: Instalar herramientas de red necesarias
# -----------------------------------------------------------------------
log_info "Instalando herramientas de red (nftables, iproute2, etc.)..."
apt-get install -y -qq \
    nftables \
    iproute2 \
    iputils-ping \
    net-tools \
    traceroute \
    curl \
    tcpdump \
    dnsutils
log_ok "Herramientas de red instaladas."

# -----------------------------------------------------------------------
# Paso 8: Habilitar nftables en el arranque
# -----------------------------------------------------------------------
log_info "Habilitando nftables en el arranque del sistema..."
systemctl enable nftables 2>/dev/null || true
log_ok "nftables habilitado."

# -----------------------------------------------------------------------
# Paso 9: Crear directorios necesarios
# -----------------------------------------------------------------------
log_info "Creando estructura de directorios..."
mkdir -p /root/backups/rlimengano/netplan
mkdir -p /root/backups/rlimengano/nftables
mkdir -p /root/backups/rlimengano/logs
chmod -R 700 /root/backups/rlimengano
log_ok "Directorios de backup creados en /root/backups/rlimengano/"

# -----------------------------------------------------------------------
# Paso 10: Crear directorio de logs del proyecto
# -----------------------------------------------------------------------
if [[ -d "${REPO_DIR}" ]]; then
    mkdir -p "${REPO_DIR}/logs"
    log_ok "Directorio de logs creado en ${REPO_DIR}/logs/"
fi

# -----------------------------------------------------------------------
# Resumen final
# -----------------------------------------------------------------------
echo ""
echo "========================================================"
echo "  Bootstrap completado exitosamente"
echo "========================================================"
echo ""
log_ok "Git        : $(git --version)"
log_ok "Python3    : $(python3 --version)"
log_ok "Ansible    : $(ansible --version | head -1)"
log_ok "nftables   : $(nft --version 2>&1 | head -1)"
echo ""
echo "  SIGUIENTE PASO:"
echo "  Ejecutar el playbook principal:"
echo ""
echo "  cd ${REPO_DIR}"
echo "  ansible-playbook -i inventories/local/hosts.yml \\"
echo "    playbooks/01_configurar_rlimengano.yml --ask-become-pass"
echo ""
echo "  Para solo validar (sin cambios):"
echo "  ansible-playbook -i inventories/local/hosts.yml \\"
echo "    playbooks/99_validar_rlimengano.yml --ask-become-pass"
echo ""
echo "========================================================"
