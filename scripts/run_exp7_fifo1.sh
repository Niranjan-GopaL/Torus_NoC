#!/bin/bash
# =============================================================================
# run_exp7_fifo1.sh — Minimum-buffer test (FIFO_DEPTH=1)
#
# WHAT THIS MEASURES
#   FIFO_DEPTH=1 turns each router into a fully-pipelined pass-through with no
#   intra-router buffering. Any contention immediately propagates upstream as
#   backpressure. This is the worst-case design point for area, and reveals
#   how flow-control-friendly each routing algorithm is.
#
# FIXED  : FIFO_DEPTH=1, BP_READY=70%, BP_HOTSPOT=10%
# SWEEP  : All 6 patterns × 3 routing algorithms
#
# OUTPUT
#   - Appended Markdown table in results.md
#   - Raw rows tagged "Exp7" in results_workload.csv
# =============================================================================
set -u

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
RESULTS="$RESULTS_FILE"
CSV_FILE="$RESULTS_CSV"
DATE_TAG="$(date +'%Y-%m-%d %H:%M')"

cleanup() {
    echo ""
    echo "[cleanup] Restoring sources to baseline..."
    bash "$SCRIPTS_DIR/switch_routing.sh"  custom        >/dev/null || true
    bash "$SCRIPTS_DIR/switch_workload.sh" UNIFORM_RANDOM 70 10 >/dev/null || true
    sed -i "s|parameter int FIFO_DEPTH = [0-9]\+|parameter int FIFO_DEPTH = 64|" "$SRC_DIR/torus_4x4.sv"
}
trap cleanup EXIT INT TERM

ALGOS=(Custom XY Odd-Even)
ALGO_TAGS=(custom xy oddeven)
PATTERNS=(UNIFORM_RANDOM HOTSPOT BIT_COMPLEMENT TORNADO MATRIX_TRANSPOSE NEIGHBOR_BURST)
# FIFO=1 raises contention; HOTSPOT at FIFO=2 needed ~3800 cycles already.
# 200000ns ≈ 50000 cycles is the safe upper bound.
SIM_NS=200000

echo ""
echo "############################################################"
echo "# Experiment 7: FIFO_DEPTH=1 minimum-buffer case"
echo "############################################################"

{
    echo ""
    echo ""
    echo "# Experiment 7: Minimum-Buffer Case (FIFO_DEPTH=1)"
    echo "_Run: $DATE_TAG, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=1, sim=${SIM_NS}ns_"
    echo "_How well does the network behave when each router has a single-flit buffer?_"
    echo ""
    echo "| Pattern | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|"
} >> "$RESULTS"

for PAT in "${PATTERNS[@]}"; do
    LINE="| $PAT |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp7: $ALGO routing, $PAT, FIFO=1"
        ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
              bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" "$PAT" 70 10 1 "$SIM_NS")
        echo "  -> $ROW"
        echo "Exp7,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

echo ""
echo "[done] Exp7 appended to $RESULTS"
