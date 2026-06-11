#!/usr/bin/env bash
# =============================================================================
# jhalex-swcorelim1-ovs.sh
# Script OVS idempotente para SWCORELIM1 — Red Empresarial Lima (JHALEX)
# =============================================================================
# Propósito:
#   Crear y mantener la configuración Open vSwitch de SWCORELIM1 de forma
#   idempotente. Puede ejecutarse múltiples veces sin duplicar bridges,
#   bonds ni puertos.
#
# Estructura OVS creada:
#   br-core (bridge, RSTP habilitado)
#   ├── bond-pcsc1-sc2  (ens36 + ens37, balance-slb) → SWCORELIM2
#   ├── bond-pcsc1-sd1  (ens38 + ens39, balance-slb) → SWDISTLIM1
#   ├── bond-pcsc1-sd2  (ens40 + ens41, balance-slb) → SWDISTLIM2
#   └── int-core-test   (internal, 10.255.21.1/30)   → pruebas Core-Core
#
# Uso:
#   sudo bash /usr/local/sbin/jhalex-swcorelim1-ovs.sh
#
# Instalado como servicio systemd:
#   jhalex-swcorelim1-ovs.service
#
# PROHIBIDO en este script:
#   - Eliminar br-core (solo rollback manual)
#   - Configurar VLANs, OSPF, VRRP, LACP, ACLs
#   - Tocar ens34 o ens35 (son interfaces L3, no pertenecen a OVS)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colores y helpers
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Verificar que se ejecuta como root
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root: sudo bash $0"
fi

# ---------------------------------------------------------------------------
# Verificar que openvswitch-switch está activo
# ---------------------------------------------------------------------------
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
# PASO 0: Validar que las interfaces físicas requeridas existen
# ===========================================================================
log_step "PASO 0: Validando interfaces físicas requeridas (ens34..ens41)"

REQUIRED_INTERFACES=(ens34 ens35 ens36 ens37 ens38 ens39 ens40 ens41)
MISSING_INTERFACES=()

for iface in "${REQUIRED_INTERFACES[@]}"; do
    if ip link show "$iface" &>/dev/null; then
        log_ok "Interfaz ${iface}: PRESENTE"
    else
        log_warn "Interfaz ${iface}: NO ENCONTRADA"
        MISSING_INTERFACES+=("$iface")
    fi
done

# Solo advertir por interfaces OVS faltantes (ens36..ens41).
# ens34 y ens35 son L3 y deben existir siempre.
if ip link show ens34 &>/dev/null; then
    log_ok "ens34 (enlace RLIM1): OK — NO se tocará con OVS."
else
    log_error "CRÍTICO: ens34 no existe. Abortar para evitar pérdida de conectividad."
fi

if ip link show ens35 &>/dev/null; then
    log_ok "ens35 (enlace RLIM2): OK — NO se tocará con OVS."
else
    log_warn "ens35 no existe. Continuar, pero el enlace RLIM2 no estará disponible."
fi

OVS_IFACES=(ens36 ens37 ens38 ens39 ens40 ens41)
for iface in "${OVS_IFACES[@]}"; do
    if ! ip link show "$iface" &>/dev/null; then
        log_warn "Interfaz OVS ${iface} no encontrada. El bond asociado tendrá un miembro menos."
    fi
done

echo ""

# ===========================================================================
# PASO 1: Crear bridge br-core (idempotente)
# ===========================================================================
log_step "PASO 1: Bridge br-core"

if ovs-vsctl br-exists br-core; then
    log_warn "br-core ya existe. No se recrea."
else
    ovs-vsctl add-br br-core
    log_ok "Bridge br-core creado."
fi

# Habilitar RSTP en br-core
ovs-vsctl set bridge br-core rstp_enable=true
log_ok "RSTP habilitado en br-core."

# Deshabilitar STP clásico (RSTP lo reemplaza)
ovs-vsctl set bridge br-core stp_enable=false
log_ok "STP clásico deshabilitado (RSTP activo)."

echo ""

# ===========================================================================
# PASO 2: Bond Core1-Core2 — bond-pcsc1-sc2 (ens36 + ens37)
# ===========================================================================
log_step "PASO 2: Bond bond-pcsc1-sc2 (Core → SWCORELIM2)"

# Verificar si el puerto ya existe en el bridge
if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sc2$"; then
    log_warn "bond-pcsc1-sc2 ya existe en br-core. No se recrea."
else
    # Construir comando add-bond con miembros disponibles
    BOND_SC2_MEMBERS=()
    for iface in ens36 ens37; do
        if ip link show "$iface" &>/dev/null; then
            BOND_SC2_MEMBERS+=("$iface")
        else
            log_warn "ens${iface#ens} no disponible. Excluido de bond-pcsc1-sc2."
        fi
    done

    if [[ ${#BOND_SC2_MEMBERS[@]} -ge 1 ]]; then
        ovs-vsctl add-bond br-core bond-pcsc1-sc2 "${BOND_SC2_MEMBERS[@]}" \
            bond_mode=balance-slb
        log_ok "bond-pcsc1-sc2 creado con miembros: ${BOND_SC2_MEMBERS[*]}"
    else
        log_warn "Ningún miembro disponible para bond-pcsc1-sc2. Bond no creado."
    fi
fi

# Configurar modo si el bond existe (idempotente)
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
    log_warn "bond-pcsc1-sd1 ya existe en br-core. No se recrea."
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
        ovs-vsctl add-bond br-core bond-pcsc1-sd1 "${BOND_SD1_MEMBERS[@]}" \
            bond_mode=balance-slb
        log_ok "bond-pcsc1-sd1 creado con miembros: ${BOND_SD1_MEMBERS[*]}"
    else
        log_warn "Ningún miembro disponible para bond-pcsc1-sd1. Bond no creado."
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
    log_warn "bond-pcsc1-sd2 ya existe en br-core. No se recrea."
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
        ovs-vsctl add-bond br-core bond-pcsc1-sd2 "${BOND_SD2_MEMBERS[@]}" \
            bond_mode=balance-slb
        log_ok "bond-pcsc1-sd2 creado con miembros: ${BOND_SD2_MEMBERS[*]}"
    else
        log_warn "Ningún miembro disponible para bond-pcsc1-sd2. Bond no creado."
    fi
fi

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^bond-pcsc1-sd2$"; then
    ovs-vsctl set port bond-pcsc1-sd2 bond_mode=balance-slb
    log_ok "Modo balance-slb confirmado en bond-pcsc1-sd2."
fi

echo ""

# ===========================================================================
# PASO 5: Puerto interno int-core-test con IP 10.255.21.1/30
# ===========================================================================
log_step "PASO 5: Puerto interno int-core-test (10.255.21.1/30)"

if ovs-vsctl list-ports br-core 2>/dev/null | grep -q "^int-core-test$"; then
    log_warn "int-core-test ya existe en br-core. No se recrea."
else
    ovs-vsctl add-port br-core int-core-test \
        -- set interface int-core-test type=internal
    log_ok "Puerto interno int-core-test creado."
fi

# Asignar IP al puerto interno (idempotente: ip addr replace)
ip addr replace 10.255.21.1/30 dev int-core-test 2>/dev/null || \
    ip addr add 10.255.21.1/30 dev int-core-test 2>/dev/null || \
    log_warn "IP 10.255.21.1/30 ya asignada o error. Verificar: ip addr show int-core-test"

ip link set int-core-test up 2>/dev/null || true
log_ok "int-core-test up con 10.255.21.1/30"

echo ""

# ===========================================================================
# PASO 6: Asegurar que ens36..ens41 estén UP para OVS
# ===========================================================================
log_step "PASO 6: Levantar interfaces físicas OVS (ens36..ens41)"

for iface in ens36 ens37 ens38 ens39 ens40 ens41; do
    if ip link show "$iface" &>/dev/null; then
        ip link set "$iface" up 2>/dev/null || true
        log_ok "${iface}: UP"
    fi
done

echo ""

# ===========================================================================
# PASO 7: Mostrar estado final de OVS
# ===========================================================================
log_step "PASO 7: Estado final de Open vSwitch"
echo ""
echo "--- ovs-vsctl show ---"
ovs-vsctl show
echo ""
echo "--- ovs-appctl bond/show ---"
ovs-appctl bond/show 2>/dev/null || echo "(No hay bonds activos todavía o OVS no soporta este comando)"
echo ""

# ===========================================================================
# RESUMEN
# ===========================================================================
echo "========================================================================"
echo "  SWCORELIM1 — OVS configurado correctamente"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================================"
echo ""
echo "  Bridge   : br-core (RSTP=true)"
echo "  Bonds    : bond-pcsc1-sc2, bond-pcsc1-sd1, bond-pcsc1-sd2"
echo "  Internal : int-core-test → 10.255.21.1/30"
echo ""
echo "  PENDIENTE (hasta configurar vecinos):"
echo "    - ping 10.255.21.2    → requiere SWCORELIM2"
echo "    - bond-pcsc1-sd1 full → requiere SWDISTLIM1"
echo "    - bond-pcsc1-sd2 full → requiere SWDISTLIM2"
echo "========================================================================"
