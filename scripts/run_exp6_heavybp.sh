#!/bin/bash
# =============================================================================
# run_exp6_heavybp.sh — Heavy-backpressure stress on the worst patterns
#
# WHAT THIS MEASURES
#   At BP_READY=20% the consumer is ready only 1 cycle in 5 — the network is
#   chronically blocked at the egress. This shines a light on how well each
#   routing algorithm avoids head-of-line / hotspot pile-ups when the sink is
#   the true bottleneck. Patterns chosen: the three that already showed the
#   biggest spread between Custom and XY in Experiment 2.
#
# FIXED   : FIFO_DEPTH=8, BP_HOTSPOT_PCT=10
# SWEEP   : PATTERN ∈ {HOTSPOT, MATRIX_TRANSPOSE, BIT_COMPLEMENT}
#           BP_READY ∈ {20, 40}     (paired with 70 baseline from Exp2 in summary)
#           ALGO ∈ {Custom, XY, Odd-Even}
#
# OUTPUT
#   - Appended Markdown table in results.md
#   - Raw rows tagged "Exp6" in results_workload.csv
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
PATTERNS=(HOTSPOT MATRIX_TRANSPOSE BIT_COMPLEMENT)
BP_LEVELS=(20 40)
# At BP=20%, 16000 packets * (1/0.20) = 80000 cycles ≈ 320 µs at 4ns clock.
# Give 500 µs head-room.
SIM_NS=500000

echo ""
echo "############################################################"
echo "# Experiment 6: Heavy backpressure stress (BP=20,40%, SIM=${SIM_NS}ns)"
echo "############################################################"

{
    echo ""
    echo ""
    echo "# Experiment 6: Heavy Backpressure Stress"
    echo "_Run: $DATE_TAG, FIFO_DEPTH=8, BP_HOTSPOT=10%, sim=${SIM_NS}ns_"
    echo "_Heavy backpressure (BP_READY <= 40%) on the three patterns that diverged most in Exp2._"
    echo ""
    echo "| Pattern | BP_READY | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|---|"
} >> "$RESULTS"

for PAT in "${PATTERNS[@]}"; do
    for BP in "${BP_LEVELS[@]}"; do
        LINE="| $PAT | ${BP}% |"
        for i in 0 1 2; do
            ALGO="${ALGOS[$i]}"
            echo ""
            echo "## Exp6: $ALGO routing, $PAT, BP=$BP%"
            ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
                  bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" "$PAT" "$BP" 10 8 "$SIM_NS")
            echo "  -> $ROW"
            echo "Exp6,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
            CYC=$(echo "$ROW" | cut -d, -f6)
            AVG=$(echo "$ROW" | cut -d, -f7)
            MAX=$(echo "$ROW" | cut -d, -f9)
            LINE="$LINE $CYC / $AVG / $MAX |"
        done
        echo "$LINE" >> "$RESULTS"
    done
done

echo ""
echo "[done] Exp6 appended to $RESULTS"
