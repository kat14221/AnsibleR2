#!/usr/bin/env bash
# =============================================================================
# jhalex-swcorelim1-ovs.sh (copia en roles/swcorelim1/files/)
# Script OVS idempotente para SWCORELIM1 — Red Empresarial Lima (JHALEX)
# =============================================================================
# Este archivo es copiado por Ansible al destino:
#   /usr/local/sbin/jhalex-swcorelim1-ovs.sh
#
# Ver la versión canónica y documentada en:
#   scripts/jhalex-swcorelim1-ovs.sh
# =============================================================================

set -euo pipefail

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

if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root: sudo bash $0"
fi

if ! systemctl is-active --quiet openvswitch-switch; then
    log_error "openvswitch-switch no está activo. Ejecutar: systemctl start openvswitch-switch"
fi

echo ""
echo "========================================================================"
echo "  SWCORELIM1 — Configuración Open vSwitch (JHALEX)"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================================"
echo ""

# ===========================================================================
# PASO 0: Validar interfaces
# ===========================================================================
log_step "PASO 0: Validando interfaces físicas (ens34..ens41)"

REQUIRED_INTERFACES=(ens34 ens35 ens36 ens37 ens38 ens39 ens40 ens41)

for iface in "${REQUIRED_INTERFACES[@]}"; do
    if ip link show "$iface" &>/dev/null; then
        log_ok "Interfaz ${iface}: PRESENTE"
    else
        log_warn "Interfaz ${iface}: NO ENCONTRADA"
    fi
done

if ! ip link show ens34 &>/dev/null; then
    log_error "CRÍTICO: ens34 no existe. Abortar para no perder conectividad."
fi

echo ""

# ===========================================================================
# PASO 1: Bridge br-core
# ===========================================================================
log_step "PASO 1: Bridge br-core"

if ovs-vsctl br-exists br-core; then
    log_warn "br-core ya existe. No se recrea."
else
    ovs-vsctl add-br br-core
    log_ok "Bridge br-core creado."
fi

ovs-vsctl set bridge br-core rstp_enable=true
ovs-vsctl set bridge br-core stp_enable=false
log_ok "RSTP habilitado, STP clásico deshabilitado."

echo ""

# ===========================================================================
# PASO 2: Bond Core1-Core2 — bond-pcsc1-sc2 (ens36 + ens37)
# ===========================================================================
log_step "PASO 2: Bond bond-pcsc1-sc2 (Core → SWCORELIM2)"

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sc2$"; then
    log_warn "bond-pcsc1-sc2 ya existe. No se recrea."
else
    BOND_SC2_MEMBERS=()
    for iface in ens36 ens37; do
        if ip link show "$iface" &>/dev/null; then
            BOND_SC2_MEMBERS+=("$iface")
        else
            log_warn "${iface} no disponible. Excluido de bond-pcsc1-sc2."
        fi
    done

    if [[ ${#BOND_SC2_MEMBERS[@]} -ge 1 ]]; then
        ovs-vsctl add-bond br-core bond-pcsc1-sc2 "${BOND_SC2_MEMBERS[@]}" bond_mode=balance-slb
        log_ok "bond-pcsc1-sc2 creado con: ${BOND_SC2_MEMBERS[*]}"
    else
        log_warn "Sin miembros para bond-pcsc1-sc2. Bond no creado."
    fi
fi

# Confirmar modo (solo si el bond existe; if evita abort por set -e)
if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sc2$"; then
    ovs-vsctl set port bond-pcsc1-sc2 bond_mode=balance-slb
    log_ok "Modo balance-slb confirmado en bond-pcsc1-sc2."
fi

echo ""

# ===========================================================================
# PASO 3: Bond Core1-Dist1 — bond-pcsc1-sd1 (ens38 + ens39)
# ===========================================================================
log_step "PASO 3: Bond bond-pcsc1-sd1 (Core → SWDISTLIM1)"

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sd1$"; then
    log_warn "bond-pcsc1-sd1 ya existe. No se recrea."
else
    BOND_SD1_MEMBERS=()
    for iface in ens38 ens39; do
        if ip link show "$iface" &>/dev/null; then
            BOND_SD1_MEMBERS+=("$iface")
        else
            log_warn "${iface} no disponible. Excluido de bond-pcsc1-sd1."
        fi
    done

    if [[ ${#BOND_SD1_MEMBERS[@]} -ge 1 ]]; then
        ovs-vsctl add-bond br-core bond-pcsc1-sd1 "${BOND_SD1_MEMBERS[@]}" bond_mode=balance-slb
        log_ok "bond-pcsc1-sd1 creado con: ${BOND_SD1_MEMBERS[*]}"
    else
        log_warn "Sin miembros para bond-pcsc1-sd1. Bond no creado."
    fi
fi

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sd1$"; then
    ovs-vsctl set port bond-pcsc1-sd1 bond_mode=balance-slb
    log_ok "Modo balance-slb confirmado en bond-pcsc1-sd1."
fi

echo ""

# ===========================================================================
# PASO 4: Bond Core1-Dist2 — bond-pcsc1-sd2 (ens40 + ens41)
# ===========================================================================
log_step "PASO 4: Bond bond-pcsc1-sd2 (Core → SWDISTLIM2)"

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sd2$"; then
    log_warn "bond-pcsc1-sd2 ya existe. No se recrea."
else
    BOND_SD2_MEMBERS=()
    for iface in ens40 ens41; do
        if ip link show "$iface" &>/dev/null; then
            BOND_SD2_MEMBERS+=("$iface")
        else
            log_warn "${iface} no disponible. Excluido de bond-pcsc1-sd2."
        fi
    done

    if [[ ${#BOND_SD2_MEMBERS[@]} -ge 1 ]]; then
        ovs-vsctl add-bond br-core bond-pcsc1-sd2 "${BOND_SD2_MEMBERS[@]}" bond_mode=balance-slb
        log_ok "bond-pcsc1-sd2 creado con: ${BOND_SD2_MEMBERS[*]}"
    else
        log_warn "Sin miembros para bond-pcsc1-sd2. Bond no creado."
    fi
fi

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sd2$"; then
    ovs-vsctl set port bond-pcsc1-sd2 bond_mode=balance-slb
    log_ok "Modo balance-slb confirmado en bond-pcsc1-sd2."
fi

echo ""

# ===========================================================================
# PASO 5: Puerto interno int-core-test (10.255.21.1/30)
# ===========================================================================
log_step "PASO 5: Puerto interno int-core-test"

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^int-core-test$"; then
    log_warn "int-core-test ya existe. No se recrea."
else
    ovs-vsctl add-port br-core int-core-test -- set interface int-core-test type=internal
    log_ok "Puerto interno int-core-test creado."
fi

ip addr replace 10.255.21.1/30 dev int-core-test 2>/dev/null || \
    ip addr add 10.255.21.1/30 dev int-core-test 2>/dev/null || \
    log_warn "IP 10.255.21.1/30 ya asignada (normal)."

ip link set int-core-test up 2>/dev/null || true
log_ok "int-core-test UP con 10.255.21.1/30"

echo ""

# ===========================================================================
# PASO 6: Levantar interfaces físicas OVS
# ===========================================================================
log_step "PASO 6: Levantar interfaces físicas OVS"

for iface in ens36 ens37 ens38 ens39 ens40 ens41; do
    ip link show "$iface" &>/dev/null && { ip link set "$iface" up 2>/dev/null || true; log_ok "${iface}: UP"; }
done

echo ""

# ===========================================================================
# PASO 7: Estado final
# ===========================================================================
log_step "PASO 7: Estado final de OVS"
echo ""
echo "--- ovs-vsctl show ---"
ovs-vsctl show
echo ""
echo "--- ovs-appctl bond/show ---"
ovs-appctl bond/show 2>/dev/null || echo "(Sin bonds activos todavía)"
echo ""

echo "========================================================================"
echo "  SWCORELIM1 — OVS configurado"
echo "  Bridge: br-core | Bonds: sc2, sd1, sd2 | Internal: int-core-test"
echo "  PENDIENTE: ping 10.255.21.2 (SWCORELIM2), bonds sd1/sd2 (DIST)"
echo "========================================================================"
