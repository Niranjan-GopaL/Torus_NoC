#!/bin/bash
# =============================================================================
# run_exp1_sweep.sh — Experiment 1: FIFO Depth Sweep for one routing algorithm
#
# Sweeps FIFO_DEPTH in {2, 4, 8, 16, 32, 64} for whichever routing algorithm is
# currently uncommented in router_fifo.sv (xy_route_logic module).
#
# Safety:
#   - results.md is APPEND-ONLY (uses `>>` only).
#   - rm targets are explicit named paths (no globs anywhere near the project).
#   - trap restores router_fifo.sv from .orig on any exit (normal or abort).
#   - sed change is verified before launching Vivado.
# =============================================================================
set -u

# ---- Config ----
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
mkdir -p "$SCRATCH_DIR/tcl" "$SCRATCH_DIR/logs"
# IMPORTANT: edit torus_4x4.sv (NOT router_fifo.sv).
# The testbench instantiates `torus_4x4 dut(...)` without overriding FIFO_DEPTH,
# so the only value that matters is torus_4x4's default. The same parameter
# in torus_router_5x5 (router_fifo.sv:799) is always overridden by torus_4x4.
DEPTH_FILE="$SRC_DIR/torus_4x4.sv"
# RESULTS_FILE is exported by scripts/_env.sh -> $DOCS_DIR/results.md

# Which algorithm label to use in the result table.
# Default: take from $1 (or "Custom" if not provided).
ALGO_LABEL="${1:-Custom}"

FIFO_DEPTHS=(2 4 8 16 32 64)

# ---- Safety: backup + trap restore ----
if [ ! -f "$DEPTH_FILE" ]; then
    echo "ERROR: $DEPTH_FILE not found"
    exit 1
fi
if [ ! -f "$PROJ_XPR" ]; then
    echo "ERROR: $PROJ_XPR not found — re-run create_project.tcl first"
    exit 1
fi

cp "$DEPTH_FILE" "$DEPTH_FILE.orig"

cleanup() {
    if [ -f "$DEPTH_FILE.orig" ]; then
        cp "$DEPTH_FILE.orig" "$DEPTH_FILE"
        rm -f "$DEPTH_FILE.orig"
        echo "[cleanup] Restored torus_4x4.sv to original."
    fi
}
trap cleanup EXIT INT TERM

# ---- Append header to results.md (NEVER OVERWRITE) ----
DATE_TAG="$(date +'%Y-%m-%d %H:%M')"
{
    echo ""
    echo ""
    echo "# Experiment 1: $ALGO_LABEL Routing — FIFO Depth Sweep"
    echo "_Run: $DATE_TAG, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_"
    echo ""
    echo "| FIFO Depth | Cycles Taken |"
    echo "|---|---|"
} >> "$RESULTS_FILE"

echo "============================================"
echo "Experiment 1: $ALGO_LABEL Routing — FIFO sweep"
echo "============================================"

for DEPTH in "${FIFO_DEPTHS[@]}"; do
    echo ""
    echo "--- FIFO_DEPTH=$DEPTH ---"

    # Restore from .orig, then edit. This ensures every iteration starts clean.
    cp "$DEPTH_FILE.orig" "$DEPTH_FILE"
    # Value-agnostic: match the existing FIFO_DEPTH = <number> regardless of
    # what number is currently there. Bracket regex requires sed -E or
    # backslashes; using POSIX BRE form so it works on stock GNU sed.
    sed -i "s|parameter int FIFO_DEPTH = [0-9]\+|parameter int FIFO_DEPTH = $DEPTH|" "$DEPTH_FILE"

    # VERIFY the edit landed
    if ! grep -q "parameter int FIFO_DEPTH = $DEPTH$" "$DEPTH_FILE"; then
        echo "  ERROR: sed did not change FIFO_DEPTH to $DEPTH in torus_4x4.sv"
        echo "| $DEPTH | SED_FAILED |" >> "$RESULTS_FILE"
        continue
    fi
    echo "  [ok] FIFO_DEPTH set to $DEPTH in torus_4x4.sv"

    # Clear ONLY caches (explicit named dirs — never glob)
    rm -rf "$PROJ_DIR/Torus_4x4_extensive_tests.sim"
    rm -rf "$PROJ_DIR/Torus_4x4_extensive_tests.cache"
    rm -rf "$PROJ_DIR/.Xil"

    # TCL for this run
    TCL_FILE="$SCRATCH_DIR/tcl/exp1_run_${ALGO_LABEL}_${DEPTH}.tcl"
    LOG_FILE="$SCRATCH_DIR/logs/exp1_run_${ALGO_LABEL}_${DEPTH}.log"
    cat > "$TCL_FILE" << TCL_EOF
open_project {$PROJ_XPR}
set_property generic {} [get_filesets sim_1]
set_property top tb_torus_4x4_random_bp_10k [get_filesets sim_1]
launch_simulation -mode behavioral
run 60000ns
close_sim
exit
TCL_EOF

    echo "  [run] Vivado batch (log: $LOG_FILE)..."
    "$VIVADO" -mode batch -source "$TCL_FILE" > "$LOG_FILE" 2>&1

    # Extract "CYCLES = " from $display output
    CYCLES=$(grep "CYCLES = " "$LOG_FILE" | tail -1 | sed 's/.*CYCLES = //' | tr -d ' ')

    if [ -z "$CYCLES" ]; then
        CYCLES="NO_OUTPUT"
        echo "  WARNING: no CYCLES line found. Last 5 log lines:"
        tail -5 "$LOG_FILE" | sed 's/^/    /'
    else
        echo "  [result] CYCLES=$CYCLES"
    fi

    echo "| $DEPTH | $CYCLES |" >> "$RESULTS_FILE"
done

echo ""
echo "============================================"
echo "Sweep complete. Results appended to:"
echo "  $RESULTS_FILE"
echo "============================================"

# cleanup() runs via trap
