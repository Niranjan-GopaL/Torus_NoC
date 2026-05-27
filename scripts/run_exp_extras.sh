#!/bin/bash
# =============================================================================
# run_exp_extras.sh — Master runner for Experiments 6, 7, 8, 9, 10, 11
#
# Chains all the "additional" experiments in a single batch. ~270 sims total.
# Wall-clock budget: ~2h 30min on this machine.
#
# Each child script is self-contained (own cleanup trap, own results-append).
# If one fails, subsequent ones still run unless you Ctrl-C.
# =============================================================================
set -u

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
LOG="$SCRATCH_DIR/logs/master_exp_extras.log"
mkdir -p "$(dirname "$LOG")"

date_now() { date +'%Y-%m-%d %H:%M:%S'; }

echo "================================================================"
echo "[$(date_now)] BEGIN run_exp_extras.sh"
echo "================================================================"

EXPS=(
    "run_exp6_heavybp.sh"
    "run_exp7_fifo1.sh"
    "run_exp9_fifo_heavyload.sh"
    "run_exp11_load_scaling.sh"
    "run_exp8_2d_heatmap.sh"
    "run_exp10_full_matrix.sh"
)

# Smaller experiments first so we get quick feedback. Heavy 2D and full-matrix
# sweeps go last.

for SCRIPT in "${EXPS[@]}"; do
    echo ""
    echo "================================================================"
    echo "[$(date_now)] BEGIN $SCRIPT"
    echo "================================================================"
    if bash "$SCRIPTS_DIR/$SCRIPT"; then
        echo ""
        echo "[$(date_now)] DONE  $SCRIPT"
    else
        echo ""
        echo "[$(date_now)] FAIL  $SCRIPT (exit $?) — continuing"
    fi
done

echo ""
echo "================================================================"
echo "[$(date_now)] ALL EXTRAS COMPLETE"
echo "================================================================"
