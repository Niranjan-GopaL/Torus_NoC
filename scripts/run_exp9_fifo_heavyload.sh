#!/bin/bash
# =============================================================================
# run_exp9_fifo_heavyload.sh — FIFO depth sweep under HEAVY load (BP=30%)
#
# WHAT THIS MEASURES
#   Exp1 measured FIFO depth under tb_torus_large.sv (≈ 80% BP, uniform random).
#   The Custom-routing sweet spot was FIFO=8. Does that sweet spot survive when
#   the network is heavily backpressured? Heavy BP changes which queues fill
#   up first, so the optimum buffer depth can shift.
#
# FIXED  : PATTERN=UNIFORM_RANDOM, BP_READY=30%, BP_HOTSPOT=10%
# SWEEP  : FIFO_DEPTH ∈ {1, 2, 4, 8, 16, 32, 64}, ALGO ∈ {Custom, XY, Odd-Even}
# Runs   : 7 × 3 = 21
# SIM_NS : 400000ns (16000 / 0.3 ≈ 53k cycles ≈ 213µs)
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
FIFO_DEPTHS=(1 2 4 8 16 32 64)
SIM_NS=400000

echo ""
echo "############################################################"
echo "# Experiment 9: FIFO depth under heavy load (BP=30%, 21 runs)"
echo "############################################################"

{
    echo ""
    echo ""
    echo "# Experiment 9: FIFO Depth Sweep under Heavy Load"
    echo "_Run: $DATE_TAG, PATTERN=UNIFORM_RANDOM, BP_READY=30%, BP_HOTSPOT=10%, sim=${SIM_NS}ns_"
    echo "_Does Exp1's FIFO=8 sweet spot survive when the network is choked?_"
    echo ""
    echo "| FIFO Depth | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|"
} >> "$RESULTS"

for FIFO in "${FIFO_DEPTHS[@]}"; do
    LINE="| $FIFO |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp9: $ALGO routing, FIFO=$FIFO, BP=30%"
        ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
              bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" UNIFORM_RANDOM 30 10 "$FIFO" "$SIM_NS")
        echo "  -> $ROW"
        echo "Exp9,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

echo ""
echo "[done] Exp9 appended to $RESULTS"
