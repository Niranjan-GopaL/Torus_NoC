#!/bin/bash
# =============================================================================
# run_full_rerun.sh — Re-run EVERY experiment after the Odd-Even fix
#
# WHY THIS EXISTS
#   Prior to 2026-05-27 the Odd-Even routing implementation was effectively
#   XY (same X-first decision tree in both column-parity branches). With the
#   fix applied to router_fifo.sv lines 47-93, every previously gathered
#   Odd-Even number is invalid and Custom-vs-XY-vs-Odd-Even comparisons need
#   to be redone.
#
# WHAT IT DOES
#   Runs, in order:
#     Experiment 1  (FIFO sweep, tb_torus_large.sv)  — 6 × 3 = 18 sims
#     Experiments 2-5  (run_exp_all.sh)              — 75 sims
#     Experiments 6-11 (run_exp_extras.sh)           — 270 sims
#   Total: ~360 simulations. Wall clock ~3-4 hours on this host.
#
# Each child script is self-contained (own cleanup trap, own results-append).
# If one script exits non-zero, the master continues to the next.
# =============================================================================
set -u

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
LOG="$SCRATCH_DIR/logs/master_full_rerun.log"
mkdir -p "$(dirname "$LOG")"

date_now() { date +'%Y-%m-%d %H:%M:%S'; }

echo "================================================================"
echo "[$(date_now)] BEGIN run_full_rerun.sh (post Odd-Even fix)"
echo "================================================================"

# ----------------------------------------------------------------------------
# Experiment 1 — FIFO depth sweep for each routing algorithm
#   Uses tb_torus_large.sv (top: tb_torus_4x4_random_bp_10k)
# ----------------------------------------------------------------------------
echo ""
echo "================================================================"
echo "[$(date_now)] BEGIN Experiment 1 (FIFO sweep × 3 algos)"
echo "================================================================"

for ALGO_PAIR in "custom:Custom" "xy:XY" "oddeven:Odd-Even"; do
    TAG=${ALGO_PAIR%%:*}
    LABEL=${ALGO_PAIR##*:}
    echo ""
    echo "[$(date_now)] Exp1 — $LABEL"
    bash "$SCRIPTS_DIR/switch_routing.sh" "$TAG" >/dev/null
    bash "$SCRIPTS_DIR/run_exp1_sweep.sh" "$LABEL"
done
bash "$SCRIPTS_DIR/switch_routing.sh" custom >/dev/null

# ----------------------------------------------------------------------------
# Experiments 2-5 — workload variants
# ----------------------------------------------------------------------------
echo ""
echo "================================================================"
echo "[$(date_now)] BEGIN Experiments 2-5 via run_exp_all.sh"
echo "================================================================"
bash "$SCRIPTS_DIR/run_exp_all.sh"

# ----------------------------------------------------------------------------
# Experiments 6-11 — additional sweeps
# ----------------------------------------------------------------------------
echo ""
echo "================================================================"
echo "[$(date_now)] BEGIN Experiments 6-11 via run_exp_extras.sh"
echo "================================================================"
bash "$SCRIPTS_DIR/run_exp_extras.sh"

echo ""
echo "================================================================"
echo "[$(date_now)] ALL EXPERIMENTS COMPLETE"
echo "================================================================"
