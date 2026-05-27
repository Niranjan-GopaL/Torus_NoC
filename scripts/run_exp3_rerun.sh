#!/bin/bash
# =============================================================================
# run_exp3_rerun.sh — Re-run only the NA rows of Experiment 3
#
# WHY THIS EXISTS
#   In the first batch run of Exp3, BP_HOTSPOT_PCT >= 30 returned NA because
#   the testbench only emits "=== RESULTS ===" after all 16000 packets drain
#   (or MAX_CYCLES). At 30% hotspot 60000ns was not enough simulation time.
#   This script reruns ONLY HOT={30,50,70,90} for the three routing algos
#   using SIM_NS=400000 (≈100k cycles @4ns), which is comfortably above the
#   worst-case 90%-hotspot drain time.
#
# OUTPUT
#   - Appends a fresh "Experiment 3 (re-run)" markdown table to results.md
#   - Appends raw rows to results_workload.csv labelled "Exp3-rerun"
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
HOTSPOT_PCTS=(30 50 70 90)
SIM_NS=400000

echo ""
echo "############################################################"
echo "# Experiment 3 (re-run): Hotspot Intensity, SIM=${SIM_NS}ns"
echo "############################################################"

{
    echo ""
    echo ""
    echo "# Experiment 3 (re-run): Hotspot Intensity Sweep"
    echo "_Run: $DATE_TAG, PATTERN=HOTSPOT, BP_READY=70%, FIFO_DEPTH=8, sim=${SIM_NS}ns_"
    echo "_Fixes the NA rows from the original Exp3 — original 60000ns was too short for HOT>=30%._"
    echo ""
    echo "| BP_HOTSPOT_PCT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|"
} >> "$RESULTS"

for HOT in "${HOTSPOT_PCTS[@]}"; do
    LINE="| ${HOT}% |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp3-rerun: $ALGO routing, HOTSPOT $HOT% (sim=${SIM_NS}ns)"
        ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
              bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" HOTSPOT 70 "$HOT" 8 "$SIM_NS")
        echo "  -> $ROW"
        echo "Exp3-rerun,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

echo ""
echo "[done] Exp3 re-run appended to $RESULTS"
