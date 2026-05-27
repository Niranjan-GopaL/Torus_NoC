#!/bin/bash
# =============================================================================
# switch_routing.sh — set the active routing algorithm in router_fifo.sv
#
# Usage:  bash switch_routing.sh [xy|oddeven|custom]
#
# The file router_fifo.sv has three always_comb blocks inside xy_route_logic:
#   XY        : lines 31-42  (commented with "//    " prefix)
#   Odd-Even  : lines 47-93  (commented with "// " prefix)
#   Custom    : lines 99-125 (active in the golden baseline)
#
# This script always restores from .golden first, then applies sed
# transformations for the chosen target. The golden file is created
# automatically on first run.
# =============================================================================
set -eu
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

ALGO="${1:-}"
ROUTER="$SRC_DIR/router_fifo.sv"
GOLDEN="${ROUTER}.golden"

if [ -z "$ALGO" ]; then
    echo "Usage: bash switch_routing.sh [xy|oddeven|custom]"
    exit 1
fi
if [ ! -f "$ROUTER" ]; then
    echo "ERROR: $ROUTER not found"
    exit 1
fi

# Save golden baseline on first run (must be Custom-active)
if [ ! -f "$GOLDEN" ]; then
    cp "$ROUTER" "$GOLDEN"
    echo "[setup] Saved golden baseline to ${GOLDEN##*/}"
fi

# Always start fresh from the golden baseline
cp "$GOLDEN" "$ROUTER"

case "$ALGO" in
    custom)
        :  # Golden is already Custom-active
        ;;
    xy)
        # Uncomment XY block (31-42): strip "//    " after the leading 4 spaces
        sed -i '31,42 s|^    //    |    |' "$ROUTER"
        # Comment Custom block (99-125): insert "// " after leading 4 spaces
        sed -i '99,125 s|^    |    // |' "$ROUTER"
        ;;
    oddeven)
        # Uncomment Odd-Even block (47-93): strip "// "
        sed -i '47,93 s|^    // |    |' "$ROUTER"
        # Comment Custom block (99-125)
        sed -i '99,125 s|^    |    // |' "$ROUTER"
        ;;
    *)
        echo "ERROR: unknown algorithm '$ALGO'. Valid: xy | oddeven | custom"
        exit 1
        ;;
esac

# Quick sanity check: there should be exactly ONE active always_comb in xy_route_logic
ACTIVE_BLOCKS=$(awk '/^module xy_route_logic/,/^endmodule/' "$ROUTER" | grep -c '^    always_comb begin' || true)
echo "[ok] Routing set to: $ALGO  (active always_comb blocks in xy_route_logic: $ACTIVE_BLOCKS)"

if [ "$ACTIVE_BLOCKS" != "1" ]; then
    echo "WARNING: expected exactly 1 active always_comb block, found $ACTIVE_BLOCKS"
    exit 1
fi
