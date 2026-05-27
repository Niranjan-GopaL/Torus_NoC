#!/bin/bash
# =============================================================================
# run_one_workload.sh — run one tb_different_workload sim, extract metrics
#
# Usage:  bash run_one_workload.sh <ALGO> <PATTERN> <BP_READY> <BP_HOTSPOT> <FIFO_DEPTH> [SIM_NS] [PKTS_PER_SRC]
#
# Args:
#   ALGO          Routing algorithm label, e.g. Custom | XY | Odd-Even (used only for output row)
#   PATTERN       Traffic pattern enum value (see switch_workload.sh)
#   BP_READY      BP_READY_PERCENT (0..100; lower = heavier backpressure)
#   BP_HOTSPOT    BP_HOTSPOT_PCT   (0..100; HOTSPOT pattern only)
#   FIFO_DEPTH    Per-router FIFO depth, plumbed via torus_4x4.sv parameter
#   SIM_NS        OPTIONAL simulation time in ns (default 60000).
#                 Heavy workloads (HOTSPOT_PCT >= 30, BP_READY <= 50) need more
#                 time for all 16000 packets to drain. Use 200000+ in those cases.
#   PKTS_PER_SRC  OPTIONAL packets per source (default: TB's golden value = 1000)
#                 Forwarded to switch_workload.sh which seds it into the TB.
#
# Prerequisites:
#   - Project exists (run create_project.tcl)
#   - Routing algorithm in router_fifo.sv is already set (use switch_routing.sh)
#
# Output: prints ONE CSV-like row to stdout:
#   ALGO,PATTERN,BP_READY,BP_HOTSPOT,FIFO_DEPTH,CYCLES,AVG_LAT,MIN_LAT,MAX_LAT
# If any metric is missing (sim didn't finish), the field is "NA".
# =============================================================================
set -eu

ALGO="${1:?'ALGO required'}"
PATTERN="${2:?'PATTERN required'}"
BP_READY="${3:?'BP_READY required'}"
BP_HOT="${4:?'BP_HOTSPOT required'}"
FIFO_DEPTH="${5:?'FIFO_DEPTH required'}"
SIM_NS="${6:-60000}"
PKTS_PER_SRC="${7:-}"

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
DEPTH_FILE="$SRC_DIR/torus_4x4.sv"

# Set workload parameters (this restores from golden then sed-edits)
if [ -n "$PKTS_PER_SRC" ]; then
    bash "$SCRIPTS_DIR/switch_workload.sh" "$PATTERN" "$BP_READY" "$BP_HOT" "$PKTS_PER_SRC" >&2
else
    bash "$SCRIPTS_DIR/switch_workload.sh" "$PATTERN" "$BP_READY" "$BP_HOT" >&2
fi

# Set FIFO_DEPTH in torus_4x4.sv
# (we don't keep a .golden for torus_4x4.sv since it has only one knob)
sed -i "s|parameter int FIFO_DEPTH = [0-9]\+|parameter int FIFO_DEPTH = $FIFO_DEPTH|" "$DEPTH_FILE"
if ! grep -q "parameter int FIFO_DEPTH = $FIFO_DEPTH" "$DEPTH_FILE"; then
    echo "ERROR: failed to set FIFO_DEPTH=$FIFO_DEPTH in torus_4x4.sv" >&2
    exit 1
fi

# Clear Vivado caches (safe: explicit dir names)
rm -rf "$PROJ_DIR/Torus_4x4_extensive_tests.sim"
rm -rf "$PROJ_DIR/Torus_4x4_extensive_tests.cache"
rm -rf "$PROJ_DIR/.Xil"

# TCL: set sim top to tb_noc_workload_comparison, launch, run, exit
RUN_TAG="${ALGO}_${PATTERN}_BP${BP_READY}_HOT${BP_HOT}_FIFO${FIFO_DEPTH}_SIM${SIM_NS}"
TCL_FILE="$SCRATCH_DIR/tcl/${RUN_TAG}.tcl"
LOG_FILE="$SCRATCH_DIR/logs/${RUN_TAG}.log"
cat > "$TCL_FILE" << TCL_EOF
open_project {$PROJ_XPR}
set_property generic {} [get_filesets sim_1]
set_property top tb_noc_workload_comparison [get_filesets sim_1]
launch_simulation -mode behavioral
run ${SIM_NS}ns
close_sim
exit
TCL_EOF

echo "[run] $ALGO/$PATTERN BP=$BP_READY% HOT=$BP_HOT% FIFO=$FIFO_DEPTH SIM=${SIM_NS}ns ..." >&2
"$VIVADO" -mode batch -source "$TCL_FILE" > "$LOG_FILE" 2>&1

# Extract metrics from log
CYCLES=$(grep "Cycles taken" "$LOG_FILE" | tail -1 | sed 's/.*: //' | tr -d ' \r' || echo "")
AVG_LAT=$(grep -E "^.*average\s*:" "$LOG_FILE" | tail -1 | awk '{print $NF}' || echo "")
MIN_LAT=$(grep -E "^.*min\s*:" "$LOG_FILE" | tail -1 | awk '{print $NF}' || echo "")
MAX_LAT=$(grep -E "^.*max\s*:" "$LOG_FILE" | tail -1 | awk '{print $NF}' || echo "")

[ -z "$CYCLES" ]  && CYCLES="NA"
[ -z "$AVG_LAT" ] && AVG_LAT="NA"
[ -z "$MIN_LAT" ] && MIN_LAT="NA"
[ -z "$MAX_LAT" ] && MAX_LAT="NA"

# Print one CSV row to stdout
echo "$ALGO,$PATTERN,$BP_READY,$BP_HOT,$FIFO_DEPTH,$CYCLES,$AVG_LAT,$MIN_LAT,$MAX_LAT"
