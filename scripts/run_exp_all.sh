#!/bin/bash
# =============================================================================
# run_exp_all.sh — Run Experiments 2-5 across patterns / BP / FIFO / routing
#
# Each experiment varies one or two dimensions while holding the rest fixed.
# Every run appends a row to results.md inside a per-experiment markdown table.
#
# Defaults (held constant unless that experiment varies them):
#   BP_READY_PERCENT = 70
#   BP_HOTSPOT_PCT   = 10
#   FIFO_DEPTH       = 8     (Custom-routing sweet spot from Experiment 1)
# =============================================================================
set -u

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
RESULTS="$RESULTS_FILE"
DATE_TAG="$(date +'%Y-%m-%d %H:%M')"

# Build a CSV of all results so we can re-format tables easily afterwards
CSV_FILE="$RESULTS_CSV"
if [ ! -f "$CSV_FILE" ]; then
    echo "experiment,algo,pattern,bp_ready,bp_hotspot,fifo,cycles,avg_lat,min_lat,max_lat,timestamp" > "$CSV_FILE"
fi

cleanup() {
    echo ""
    echo "[cleanup] Restoring source files to baseline..."
    bash "$SCRIPTS_DIR/switch_routing.sh"  custom        >/dev/null || true
    bash "$SCRIPTS_DIR/switch_workload.sh" UNIFORM_RANDOM 70 10 >/dev/null || true
    sed -i "s|parameter int FIFO_DEPTH = [0-9]\+|parameter int FIFO_DEPTH = 64|" "$SRC_DIR/torus_4x4.sv"
    echo "[cleanup] Done. Sources reset."
}
trap cleanup EXIT INT TERM

# Helper: run one config and append a CSV/markdown row
# Args: experiment_label algo pattern bp_ready bp_hotspot fifo
run_one() {
    local EXP="$1" ALGO="$2" PATTERN="$3" BP_READY="$4" BP_HOT="$5" FIFO="$6"

    bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO,,}" >/dev/null

    local CSV_ROW
    CSV_ROW=$(bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" "$PATTERN" "$BP_READY" "$BP_HOT" "$FIFO")

    # Append to CSV file with timestamp + experiment label
    echo "$EXP,$CSV_ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
    # Also echo to stdout for live feedback
    echo "  -> $CSV_ROW"
}

# Map algo->lowercase tag used by switch_routing.sh
ALGOS=(Custom XY Odd-Even)
ALGO_TAGS=(custom xy oddeven)

# =====================================================================
# Experiment 2: Routing × Traffic Pattern
#   Fixed: BP_READY=70%, BP_HOTSPOT=10%, FIFO=8
# =====================================================================
echo ""
echo "############################################################"
echo "# Experiment 2: Routing × Traffic Pattern (FIFO=8, BP=70%)"
echo "############################################################"

PATTERNS=(UNIFORM_RANDOM HOTSPOT BIT_COMPLEMENT TORNADO MATRIX_TRANSPOSE NEIGHBOR_BURST)

{
    echo ""
    echo ""
    echo "# Experiment 2: Routing × Traffic Pattern"
    echo "_Run: $DATE_TAG, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=8, sim=60000ns_"
    echo ""
    echo "| Pattern | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|"
} >> "$RESULTS"

for PAT in "${PATTERNS[@]}"; do
    LINE="| $PAT |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp2: $ALGO routing, $PAT"
        ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
              bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" "$PAT" 70 10 8)
        echo "  -> $ROW"
        echo "Exp2,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        # ROW is ALGO,PATTERN,BP_READY,BP_HOTSPOT,FIFO_DEPTH,CYCLES,AVG_LAT,MIN_LAT,MAX_LAT
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

# =====================================================================
# Experiment 3: Hotspot Intensity Sweep
#   Fixed: PATTERN=HOTSPOT, BP_READY=70%, FIFO=8
# =====================================================================
echo ""
echo "############################################################"
echo "# Experiment 3: Hotspot Intensity (PATTERN=HOTSPOT)"
echo "############################################################"

HOTSPOT_PCTS=(10 30 50 70 90)

{
    echo ""
    echo ""
    echo "# Experiment 3: Hotspot Intensity Sweep"
    echo "_Run: $DATE_TAG, PATTERN=HOTSPOT, BP_READY=70%, FIFO_DEPTH=8, sim=60000ns_"
    echo ""
    echo "| BP_HOTSPOT_PCT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|"
} >> "$RESULTS"

for HOT in "${HOTSPOT_PCTS[@]}"; do
    # Heavier hotspot concentrates more traffic on node 0 (bandwidth-bound by
    # BP_READY_PERCENT=70%). 16000 packets / 0.7 ready ≈ 22857 cycles for the
    # extreme case alone, so 60000ns (= 15000 cycles @4ns) is not enough.
    # Use a generous 400000ns once HOT>=30%; the TB exits at $finish on
    # completion so extra time is free.
    if [ "$HOT" -ge 30 ]; then
        SIM_NS=400000
    else
        SIM_NS=60000
    fi
    LINE="| ${HOT}% |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp3: $ALGO routing, HOTSPOT $HOT% (sim=${SIM_NS}ns)"
        ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
              bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" HOTSPOT 70 "$HOT" 8 "$SIM_NS")
        echo "  -> $ROW"
        echo "Exp3,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

# =====================================================================
# Experiment 4: Backpressure Sweep
#   Fixed: PATTERN=UNIFORM_RANDOM, BP_HOTSPOT=10, FIFO=8
# =====================================================================
echo ""
echo "############################################################"
echo "# Experiment 4: Backpressure Sweep (PATTERN=UNIFORM_RANDOM)"
echo "############################################################"

BP_READY_PCTS=(30 50 70 90 100)

{
    echo ""
    echo ""
    echo "# Experiment 4: Backpressure Sweep"
    echo "_Run: $DATE_TAG, PATTERN=UNIFORM_RANDOM, FIFO_DEPTH=8, sim=60000ns_"
    echo ""
    echo "_(BP_READY_PERCENT = % of cycles the consumer is ready; lower = heavier backpressure)_"
    echo ""
    echo "| BP_READY_PERCENT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|"
} >> "$RESULTS"

for BP in "${BP_READY_PCTS[@]}"; do
    LINE="| ${BP}% |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp4: $ALGO routing, BP_READY=$BP%"
        ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
              bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" UNIFORM_RANDOM "$BP" 10 8)
        echo "  -> $ROW"
        echo "Exp4,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

# =====================================================================
# Experiment 5: FIFO Depth × Pattern × Routing (adversarial patterns)
#   Fixed: BP_READY=70, BP_HOTSPOT=10
# =====================================================================
echo ""
echo "############################################################"
echo "# Experiment 5: FIFO × Pattern × Routing (extremes)"
echo "############################################################"

ADV_PATTERNS=(HOTSPOT BIT_COMPLEMENT NEIGHBOR_BURST)
FIFO_DEPTHS=(2 8 64)

{
    echo ""
    echo ""
    echo "# Experiment 5: FIFO × Pattern × Routing"
    echo "_Run: $DATE_TAG, BP_READY=70%, BP_HOTSPOT=10%, sim=60000ns_"
    echo ""
    echo "| Pattern | FIFO | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|---|"
} >> "$RESULTS"

for PAT in "${ADV_PATTERNS[@]}"; do
    for FIFO in "${FIFO_DEPTHS[@]}"; do
        LINE="| $PAT | $FIFO |"
        for i in 0 1 2; do
            ALGO="${ALGOS[$i]}"
            echo ""
            echo "## Exp5: $ALGO routing, $PAT, FIFO=$FIFO"
            ROW=$(bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null && \
                  bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" "$PAT" 70 10 "$FIFO")
            echo "  -> $ROW"
            echo "Exp5,$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
            CYC=$(echo "$ROW" | cut -d, -f6)
            AVG=$(echo "$ROW" | cut -d, -f7)
            MAX=$(echo "$ROW" | cut -d, -f9)
            LINE="$LINE $CYC / $AVG / $MAX |"
        done
        echo "$LINE" >> "$RESULTS"
    done
done

echo ""
echo "############################################################"
echo "# All experiments complete."
echo "#  Results appended to: $RESULTS"
echo "#  Raw CSV at:          $CSV_FILE"
echo "############################################################"
