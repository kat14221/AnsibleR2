#!/usr/bin/env bash
# =============================================================================
# run_rlimengano.sh
# Script de ejecución rápida del playbook de RLIMENGANO
# =============================================================================
# Uso:
#   bash scripts/run_rlimengano.sh [opciones]
#
# Opciones:
#   --check      Modo dry-run (no aplica cambios)
#   --validate   Solo ejecuta el playbook de validación
#   --tags TAG   Ejecutar solo tareas con ese tag
#   --help       Mostrar esta ayuda
# =============================================================================

set -euo pipefail

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# -----------------------------------------------------------------------
# Detectar directorio del repositorio
# -----------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
INVENTORY="${REPO_DIR}/inventories/local/hosts.yml"
PLAYBOOK_MAIN="${REPO_DIR}/playbooks/01_configurar_rlimengano.yml"
PLAYBOOK_VALIDATE="${REPO_DIR}/playbooks/99_validar_rlimengano.yml"

# -----------------------------------------------------------------------
# Parsear argumentos
# -----------------------------------------------------------------------
MODE="main"
EXTRA_ARGS=""
TAGS_ARG=""

for arg in "$@"; do
    case $arg in
        --check)
            EXTRA_ARGS="--check --diff"
            log_warn "Modo DRY-RUN activado. No se aplicarán cambios."
            ;;
        --validate)
            MODE="validate"
            ;;
        --tags=*)
            TAGS_ARG="--tags ${arg#*=}"
            ;;
        --help|-h)
            echo "Uso: bash run_rlimengano.sh [--check] [--validate] [--tags=TAG]"
            echo ""
            echo "  --check       Modo dry-run (simula sin aplicar)"
            echo "  --validate    Ejecuta solo validaciones"
            echo "  --tags=TAG    Solo ejecuta tareas con el tag especificado"
            echo "                Tags disponibles: netplan, sysctl, nftables,"
            echo "                                 dhcp, validation, common"
            exit 0
            ;;
    esac
done

# -----------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------
echo ""
echo "========================================================"
echo "  RLIMENGANO :: Red Empresarial Lima"
echo "  ISP Secundario Simulado"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# Verificar que ansible está instalado
# -----------------------------------------------------------------------
if ! command -v ansible-playbook &>/dev/null; then
    echo "ERROR: ansible-playbook no encontrado."
    echo "Ejecutar primero: sudo bash scripts/bootstrap_rlimengano.sh"
    exit 1
fi

log_ok "Ansible: $(ansible --version | head -1)"

# -----------------------------------------------------------------------
# Verificar que el inventario existe
# -----------------------------------------------------------------------
if [[ ! -f "${INVENTORY}" ]]; then
    echo "ERROR: Inventario no encontrado: ${INVENTORY}"
    exit 1
fi

# -----------------------------------------------------------------------
# Ejecutar el playbook
# -----------------------------------------------------------------------
cd "${REPO_DIR}"

if [[ "${MODE}" == "validate" ]]; then
    log_info "Ejecutando playbook de VALIDACIÓN..."
    PLAYBOOK="${PLAYBOOK_VALIDATE}"
else
    log_info "Ejecutando playbook PRINCIPAL de configuración..."
    PLAYBOOK="${PLAYBOOK_MAIN}"
fi

echo ""
log_info "Comando: ansible-playbook -i ${INVENTORY} ${PLAYBOOK} ${TAGS_ARG} ${EXTRA_ARGS} --ask-become-pass"
echo ""

# shellcheck disable=SC2086
ansible-playbook \
    -i "${INVENTORY}" \
    "${PLAYBOOK}" \
    ${TAGS_ARG} \
    ${EXTRA_ARGS} \
    --ask-become-pass

echo ""
log_ok "Playbook finalizado."
echo "========================================================"
