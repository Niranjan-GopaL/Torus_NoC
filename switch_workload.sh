#!/bin/bash
# =============================================================================
# switch_workload.sh — set TRAFFIC_PATTERN, BP_READY_PERCENT, BP_HOTSPOT_PCT
#                     in tb_different_workload.sv
#
# Usage:  bash switch_workload.sh <PATTERN> <BP_READY_PERCENT> <BP_HOTSPOT_PCT>
#
# Valid patterns: UNIFORM_RANDOM | HOTSPOT | BIT_COMPLEMENT | TORNADO
#                 MATRIX_TRANSPOSE | NEIGHBOR_BURST
# =============================================================================
set -eu

PATTERN="${1:?'PATTERN required'}"
BP_READY="${2:?'BP_READY_PERCENT required'}"
BP_HOT="${3:?'BP_HOTSPOT_PCT required'}"

TB="/home/nira/Documents/code/swe/claude_code_project/noc_project/final/tb_different_workload.sv"
GOLDEN="${TB}.golden"

if [ ! -f "$TB" ]; then
    echo "ERROR: $TB not found"
    exit 1
fi

# Snapshot the golden baseline once
if [ ! -f "$GOLDEN" ]; then
    cp "$TB" "$GOLDEN"
    echo "[setup] Saved golden baseline to ${GOLDEN##*/}"
fi

# Restore baseline before editing
cp "$GOLDEN" "$TB"

# Validate pattern
case "$PATTERN" in
    UNIFORM_RANDOM|HOTSPOT|BIT_COMPLEMENT|TORNADO|MATRIX_TRANSPOSE|NEIGHBOR_BURST) ;;
    *) echo "ERROR: invalid pattern '$PATTERN'"; exit 1 ;;
esac

# sed each parameter (these are localparam declarations near top of TB)
# Line 40: localparam traffic_pattern_t TRAFFIC_PATTERN = <X>;
# Line 42: localparam int BP_READY_PERCENT = <N>;
# Line 43: localparam int BP_HOTSPOT_PCT   = <N>;
sed -i "s|localparam traffic_pattern_t TRAFFIC_PATTERN = .*;|localparam traffic_pattern_t TRAFFIC_PATTERN = $PATTERN;|" "$TB"
sed -i "s|localparam int BP_READY_PERCENT = .*;|localparam int BP_READY_PERCENT = $BP_READY;|" "$TB"
sed -i "s|localparam int BP_HOTSPOT_PCT   = .*;|localparam int BP_HOTSPOT_PCT   = $BP_HOT;|" "$TB"

# Sanity check the edits landed
if ! grep -q "TRAFFIC_PATTERN = $PATTERN;" "$TB"; then
    echo "ERROR: failed to set TRAFFIC_PATTERN"; exit 1
fi
if ! grep -q "BP_READY_PERCENT = $BP_READY;" "$TB"; then
    echo "ERROR: failed to set BP_READY_PERCENT"; exit 1
fi
if ! grep -q "BP_HOTSPOT_PCT   = $BP_HOT;" "$TB"; then
    echo "ERROR: failed to set BP_HOTSPOT_PCT"; exit 1
fi

echo "[ok] Workload: PATTERN=$PATTERN  BP_READY=$BP_READY%  BP_HOTSPOT=$BP_HOT%"
