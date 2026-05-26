#!/bin/bash
# =============================================================================
# run_one_workload.sh — run one tb_different_workload sim, extract metrics
#
# Usage:  bash run_one_workload.sh <ALGO> <PATTERN> <BP_READY> <BP_HOTSPOT> <FIFO_DEPTH>
#
# Prerequisites:
#   - Project exists (run create_project.tcl)
#   - Routing algorithm in router_fifo.sv is already set (use switch_routing.sh)
#
# Output: appends one CSV-like line of results to stdout:
#   ALGO,PATTERN,BP_READY,BP_HOTSPOT,FIFO_DEPTH,CYCLES,AVG_LAT,MIN_LAT,MAX_LAT
# =============================================================================
set -eu

ALGO="${1:?'ALGO required'}"
PATTERN="${2:?'PATTERN required'}"
BP_READY="${3:?'BP_READY required'}"
BP_HOT="${4:?'BP_HOTSPOT required'}"
FIFO_DEPTH="${5:?'FIFO_DEPTH required'}"

SRC_DIR="/home/nira/Documents/code/swe/claude_code_project/noc_project/final"
PROJ_DIR="/home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests"
PROJ_XPR="$PROJ_DIR/Torus_4x4_extensive_tests.xpr"
VIVADO=/tools/Xilinx/Vivado/2024.2/bin/vivado
DEPTH_FILE="$SRC_DIR/torus_4x4.sv"

# Set workload parameters (this restores from golden then sed-edits)
bash "$SRC_DIR/switch_workload.sh" "$PATTERN" "$BP_READY" "$BP_HOT" >&2

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
TCL_FILE="/tmp/exp_workload_${ALGO}_${PATTERN}_${BP_READY}_${BP_HOT}_${FIFO_DEPTH}.tcl"
LOG_FILE="/tmp/exp_workload_${ALGO}_${PATTERN}_${BP_READY}_${BP_HOT}_${FIFO_DEPTH}.log"
cat > "$TCL_FILE" << TCL_EOF
open_project {$PROJ_XPR}
set_property generic {} [get_filesets sim_1]
set_property top tb_noc_workload_comparison [get_filesets sim_1]
launch_simulation -mode behavioral
run 60000ns
close_sim
exit
TCL_EOF

echo "[run] $ALGO/$PATTERN BP=$BP_READY% HOT=$BP_HOT% FIFO=$FIFO_DEPTH ..." >&2
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
