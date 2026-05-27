#!/bin/bash
# =============================================================================
# switch_workload.sh — set TRAFFIC_PATTERN, BP_READY_PERCENT, BP_HOTSPOT_PCT
#                     (and optionally PKTS_PER_SRC) in tb_different_workload.sv
#
# Usage:  bash switch_workload.sh <PATTERN> <BP_READY_PERCENT> <BP_HOTSPOT_PCT> [PKTS_PER_SRC]
#
# Valid patterns: UNIFORM_RANDOM | HOTSPOT | BIT_COMPLEMENT | TORNADO
#                 MATRIX_TRANSPOSE | NEIGHBOR_BURST
#
# If PKTS_PER_SRC is omitted, the golden baseline value (1000) is used.
# =============================================================================
set -eu
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

PATTERN="${1:?'PATTERN required'}"
BP_READY="${2:?'BP_READY_PERCENT required'}"
BP_HOT="${3:?'BP_HOTSPOT_PCT required'}"
PKTS_PER_SRC="${4:-}"

TB="$TB_DIR/tb_different_workload.sv"
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

if [ -n "$PKTS_PER_SRC" ]; then
    sed -i "s|localparam int PKTS_PER_SRC = [0-9]\+;|localparam int PKTS_PER_SRC = $PKTS_PER_SRC;|" "$TB"
fi

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
if [ -n "$PKTS_PER_SRC" ] && ! grep -q "PKTS_PER_SRC = $PKTS_PER_SRC;" "$TB"; then
    echo "ERROR: failed to set PKTS_PER_SRC"; exit 1
fi

if [ -n "$PKTS_PER_SRC" ]; then
    echo "[ok] Workload: PATTERN=$PATTERN  BP_READY=$BP_READY%  BP_HOTSPOT=$BP_HOT%  PKTS_PER_SRC=$PKTS_PER_SRC"
else
    echo "[ok] Workload: PATTERN=$PATTERN  BP_READY=$BP_READY%  BP_HOTSPOT=$BP_HOT%"
fi
