#!/usr/bin/env bash
# =============================================================================
# run_swcorelim1.sh
# Script de conveniencia para ejecutar el playbook de SWCORELIM1
# =============================================================================
# Uso: bash scripts/run_swcorelim1.sh [opciones]
#
# Opciones:
#   --check       Dry-run sin cambios
#   --tags TAG    Ejecutar solo tareas con tag (netplan, ovs, packages, etc.)
#   --validate    Solo ejecutar playbook de validación
# =============================================================================

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
INVENTORY="${REPO_DIR}/inventories/local/hosts.yml"
PLAYBOOK="${REPO_DIR}/playbooks/02_configurar_swcorelim1.yml"
VALIDATE_PLAYBOOK="${REPO_DIR}/playbooks/99_validar_swcorelim1.yml"

echo -e "${BLUE}"
echo "========================================================================"
echo "  SWCORELIM1 — Red Empresarial Lima (JHALEX)"
echo "  Ejecutor de Playbook Ansible"
echo "========================================================================"
echo -e "${NC}"

# Verificar que el inventario existe
if [[ ! -f "${INVENTORY}" ]]; then
    echo -e "${YELLOW}[AVISO]${NC} Inventario no encontrado: ${INVENTORY}"
    exit 1
fi

# Parsear argumentos
EXTRA_ARGS=()
VALIDATE_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --validate)
            VALIDATE_ONLY=true
            ;;
        *)
            EXTRA_ARGS+=("$arg")
            ;;
    esac
done

if [[ "$VALIDATE_ONLY" == "true" ]]; then
    echo -e "${GREEN}Ejecutando playbook de validación...${NC}"
    ansible-playbook -i "${INVENTORY}" "${VALIDATE_PLAYBOOK}" \
        --ask-become-pass "${EXTRA_ARGS[@]:-}"
else
    echo -e "${GREEN}Ejecutando playbook de configuración...${NC}"
    ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" \
        --ask-become-pass "${EXTRA_ARGS[@]:-}"
fi
