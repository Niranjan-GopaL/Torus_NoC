#!/bin/bash
# =============================================================================
# run_exp10_full_matrix.sh — Complete the Exp5 matrix: ALL patterns × ALL FIFOs
#
# WHAT THIS MEASURES
#   Exp5 only covered 3 adversarial patterns × 3 FIFO depths. This script
#   produces the full 6×7 matrix so every (pattern, FIFO) cell has data for
#   all 3 routing algorithms. The output is plot-ready CSV.
#
# FIXED  : BP_READY=70%, BP_HOTSPOT=10%
# SWEEP  : PATTERN ∈ all 6 patterns
#          FIFO_DEPTH ∈ {1, 2, 4, 8, 16, 32, 64}
#          ALGO ∈ {Custom, XY, Odd-Even}
# Runs   : 6 × 7 × 3 = 126
# SIM_NS : 200000ns (BP=70% is light, HOTSPOT @10% finishes in <16k cycles)
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
FIFO_DEPTHS=(1 2 4 8 16 32 64)
SIM_NS=200000

echo ""
echo "############################################################"
echo "# Experiment 10: Full Pattern × FIFO matrix (126 runs)"
echo "############################################################"

# One table per routing algorithm
for i in 0 1 2; do
    ALGO="${ALGOS[$i]}"
    TAG="${ALGO_TAGS[$i]}"
    bash "$SCRIPTS_DIR/switch_routing.sh" "$TAG" >/dev/null

    {
        echo ""
        echo ""
        echo "# Experiment 10 — ${ALGO} routing: Pattern × FIFO (cycles taken)"
        echo "_Run: $DATE_TAG, BP_READY=70%, BP_HOTSPOT=10%, sim=${SIM_NS}ns_"
        echo ""
        printf "| Pattern |"
        for FIFO in "${FIFO_DEPTHS[@]}"; do printf " FIFO=%s |" "$FIFO"; done
        echo ""
        printf "|---|"
        for FIFO in "${FIFO_DEPTHS[@]}"; do printf "---|"; done
        echo ""
    } >> "$RESULTS"

    for PAT in "${PATTERNS[@]}"; do
        LINE="| $PAT |"
        for FIFO in "${FIFO_DEPTHS[@]}"; do
            echo ""
            echo "## Exp10: $ALGO  $PAT  FIFO=$FIFO"
            ROW=$(bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" "$PAT" 70 10 "$FIFO" "$SIM_NS")
            echo "  -> $ROW"
            echo "Exp10,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
            CYC=$(echo "$ROW" | cut -d, -f6)
            LINE="$LINE $CYC |"
        done
        echo "$LINE" >> "$RESULTS"
    done
done

echo ""
echo "[done] Exp10 (3 matrices) appended to $RESULTS"
