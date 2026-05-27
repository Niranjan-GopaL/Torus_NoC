#!/bin/bash
# =============================================================================
# run_exp8_2d_heatmap.sh — 2D sweep of BP_READY × BP_HOTSPOT
#
# WHAT THIS MEASURES
#   The full operating-point grid for HOTSPOT traffic. For each cell we run all
#   three routing algorithms and report cycles taken. The resulting table forms
#   a heat-map of "where does each algorithm dominate".
#
# FIXED  : PATTERN=HOTSPOT, FIFO_DEPTH=8
# SWEEP  : BP_READY_PERCENT ∈ {20, 40, 70, 90, 100}     (heaviest -> none)
#          BP_HOTSPOT_PCT   ∈ {10, 30, 50, 70, 90}      (mild -> extreme)
#          ALGO             ∈ {Custom, XY, Odd-Even}
#
# Runs   : 5 × 5 × 3 = 75
# SIM_NS : adaptive — heavier cells get more time
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
BP_LEVELS=(20 40 70 90 100)
HOT_LEVELS=(10 30 50 70 90)

# Estimate SIM_NS from worst-case sink throughput:
#   cycles_needed ≈ 16000 / (BP / 100)
#   sim_ns        ≈ cycles_needed * 4ns
# Add 3x head-room.
pick_sim_ns() {
    local bp=$1
    case $bp in
        20)  echo 1000000 ;;
        40)  echo  600000 ;;
        70)  echo  400000 ;;
        90)  echo  300000 ;;
        100) echo  250000 ;;
    esac
}

echo ""
echo "############################################################"
echo "# Experiment 8: BP × HOTSPOT 2D heatmap (75 runs)"
echo "############################################################"

# Emit one markdown table per routing algorithm so each table is a clean heat-map
for i in 0 1 2; do
    ALGO="${ALGOS[$i]}"
    TAG="${ALGO_TAGS[$i]}"
    bash "$SCRIPTS_DIR/switch_routing.sh" "$TAG" >/dev/null

    {
        echo ""
        echo ""
        echo "# Experiment 8 — ${ALGO} routing: BP_READY × BP_HOTSPOT (cycles)"
        echo "_Run: $DATE_TAG, PATTERN=HOTSPOT, FIFO_DEPTH=8 (cycles only)_"
        echo ""
        printf "| BP_READY \\ BP_HOT |"
        for HOT in "${HOT_LEVELS[@]}"; do printf " %s%% |" "$HOT"; done
        echo ""
        printf "|---|"
        for HOT in "${HOT_LEVELS[@]}"; do printf "---|"; done
        echo ""
    } >> "$RESULTS"

    for BP in "${BP_LEVELS[@]}"; do
        SIM_NS=$(pick_sim_ns "$BP")
        LINE="| **${BP}%** |"
        for HOT in "${HOT_LEVELS[@]}"; do
            echo ""
            echo "## Exp8: $ALGO  BP=$BP%  HOT=$HOT%  (sim=${SIM_NS}ns)"
            ROW=$(bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" HOTSPOT "$BP" "$HOT" 8 "$SIM_NS")
            echo "  -> $ROW"
            echo "Exp8,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
            CYC=$(echo "$ROW" | cut -d, -f6)
            LINE="$LINE $CYC |"
        done
        echo "$LINE" >> "$RESULTS"
    done
done

echo ""
echo "[done] Exp8 (3 heat-maps) appended to $RESULTS"
