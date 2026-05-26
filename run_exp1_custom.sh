#!/bin/bash

# Experiment 1: Custom Routing - FIFO Depth Sweep
# Runs sims for FIFO_DEPTH in [2,4,8,16,32,64], extracts cycles, appends to results.md

PROJ_DIR="/home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests"
FINAL_DIR="/home/nira/Documents/code/swe/claude_code_project/noc_project/final"
RESULTS_FILE="$FINAL_DIR/results.md"

# Make sure we're in the project directory
cd "$PROJ_DIR"

# Fifo depths to test
FIFO_DEPTHS=(2 4 8 16 32 64)

echo "======================================"
echo "Experiment 1: Custom Routing - FIFO Sweep"
echo "======================================"

# Append header to results file
cat >> "$RESULTS_FILE" << 'EOF'


# Experiment 1: Custom Routing - FIFO Depth Sweep (60000ns run)
| FIFO Depth | Cycles Taken |
|---|---|
EOF

# Sweep over FIFO depths
for DEPTH in "${FIFO_DEPTHS[@]}"; do
    echo "Running FIFO_DEPTH=$DEPTH..."

    # Create a temporary TCL script for this run
    TCL_SCRIPT="/tmp/sim_custom_$DEPTH.tcl"
    SIM_LOG="/tmp/sim_custom_$DEPTH.log"

    cat > "$TCL_SCRIPT" << TCL_EOF
open_project {$PROJ_DIR/Torus_4x4_extensive_tests.xpr}
set_property generic {FIFO_DEPTH=$DEPTH} [get_filesets sim_1]
launch_simulation -mode behavioral
run 60000ns
close_sim
exit
TCL_EOF

    # Run Vivado batch mode
    /tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -nolog -nojournal -source "$TCL_SCRIPT" > "$SIM_LOG" 2>&1

    # Extract "CYCLES = " value from the log
    CYCLES=$(grep "CYCLES = " "$SIM_LOG" | tail -1 | sed 's/.*CYCLES = //' | tr -d ' ')

    if [ -z "$CYCLES" ]; then
        CYCLES="ERROR"
        echo "  WARNING: Could not extract cycles from log"
    fi

    echo "  FIFO_DEPTH=$DEPTH -> CYCLES=$CYCLES"

    # Append to results file
    echo "| $DEPTH | $CYCLES |" >> "$RESULTS_FILE"

    # Clean up temp TCL
    rm -f "$TCL_SCRIPT"
done

echo "======================================"
echo "Experiment 1 (Custom) complete."
echo "Results appended to $RESULTS_FILE"
echo "======================================"
