#!/bin/bash
# =============================================================================
# run_exp11_load_scaling.sh — Vary PKTS_PER_SRC to test load scaling
#
# WHAT THIS MEASURES
#   All previous experiments use PKTS_PER_SRC=1000 (16000 packets total).
#   This script varies the offered load to verify cycle/latency scale linearly
#   (or super-linearly under saturation).
#
# FIXED  : PATTERN=UNIFORM_RANDOM, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=8
# SWEEP  : PKTS_PER_SRC ∈ {200, 1000, 2000, 5000}
#          ALGO ∈ {Custom, XY, Odd-Even}
# Runs   : 4 × 3 = 12
#
# HOW IT WORKS
#   - tb_different_workload.sv has `localparam int PKTS_PER_SRC = 1000;`
#   - We sed it in place, run the sim, then restore from golden.
#   - SIM_NS is sized for the worst case: PKTS=5000 × 16 = 80000 packets at
#     0.7 ready ≈ 114k cycles ≈ 456 µs. Use 600000 ns to be safe.
# =============================================================================
set -u

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
RESULTS="$RESULTS_FILE"
CSV_FILE="$RESULTS_CSV"
DATE_TAG="$(date +'%Y-%m-%d %H:%M')"
TB="$SRC_DIR/tb_different_workload.sv"
GOLDEN="${TB}.golden"

cleanup() {
    echo ""
    echo "[cleanup] Restoring sources to baseline..."
    bash "$SCRIPTS_DIR/switch_routing.sh"  custom        >/dev/null || true
    bash "$SCRIPTS_DIR/switch_workload.sh" UNIFORM_RANDOM 70 10 >/dev/null || true
    sed -i "s|parameter int FIFO_DEPTH = [0-9]\+|parameter int FIFO_DEPTH = 64|" "$SRC_DIR/torus_4x4.sv"
    # Also restore PKTS_PER_SRC if golden exists
    if [ -f "$GOLDEN" ]; then
        local pkt
        pkt=$(grep "localparam int PKTS_PER_SRC" "$GOLDEN" | head -1 | sed 's/.*= //;s/;.*//' | tr -d ' ')
        [ -n "$pkt" ] && sed -i "s|localparam int PKTS_PER_SRC = [0-9]\+;|localparam int PKTS_PER_SRC = $pkt;|" "$TB"
    fi
}
trap cleanup EXIT INT TERM

ALGOS=(Custom XY Odd-Even)
ALGO_TAGS=(custom xy oddeven)
PKT_LEVELS=(200 1000 2000 5000)

pick_sim_ns() {
    local pkts=$1
    # cycles = (pkts * 16) / 0.7 ≈ 22.86 * pkts ; ns = cycles * 4
    # Round up generously to account for routing overhead.
    case $pkts in
        200)  echo  60000 ;;
        1000) echo 200000 ;;
        2000) echo 400000 ;;
        5000) echo 1000000 ;;
    esac
}

echo ""
echo "############################################################"
echo "# Experiment 11: Load scaling (PKTS_PER_SRC sweep)"
echo "############################################################"

# Make sure baseline params are set before we sed PKTS_PER_SRC
bash "$SCRIPTS_DIR/switch_workload.sh" UNIFORM_RANDOM 70 10 >/dev/null

{
    echo ""
    echo ""
    echo "# Experiment 11: Load Scaling (PKTS_PER_SRC sweep)"
    echo "_Run: $DATE_TAG, PATTERN=UNIFORM_RANDOM, BP_READY=70%, FIFO_DEPTH=8_"
    echo "_Cycles should scale roughly linearly with offered load if the network is unsaturated._"
    echo ""
    echo "| PKTS_PER_SRC | Total packets | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |"
    echo "|---|---|---|---|---|"
} >> "$RESULTS"

for PKTS in "${PKT_LEVELS[@]}"; do
    TOTAL=$((PKTS * 16))
    SIM_NS=$(pick_sim_ns "$PKTS")

    LINE="| $PKTS | $TOTAL |"
    for i in 0 1 2; do
        ALGO="${ALGOS[$i]}"
        echo ""
        echo "## Exp11: $ALGO routing, PKTS_PER_SRC=$PKTS (TOTAL=$TOTAL, sim=${SIM_NS}ns)"
        bash "$SCRIPTS_DIR/switch_routing.sh" "${ALGO_TAGS[$i]}" >/dev/null
        # 7th arg = PKTS_PER_SRC, forwarded through switch_workload.sh
        ROW=$(bash "$SCRIPTS_DIR/run_one_workload.sh" "$ALGO" UNIFORM_RANDOM 70 10 8 "$SIM_NS" "$PKTS")
        echo "  -> $ROW"
        echo "Exp11-pkts${PKTS},$ROW,$(date +'%H:%M:%S')" >> "$CSV_FILE"
        CYC=$(echo "$ROW" | cut -d, -f6)
        AVG=$(echo "$ROW" | cut -d, -f7)
        MAX=$(echo "$ROW" | cut -d, -f9)
        LINE="$LINE $CYC / $AVG / $MAX |"
    done
    echo "$LINE" >> "$RESULTS"
done

echo ""
echo "[done] Exp11 appended to $RESULTS"
