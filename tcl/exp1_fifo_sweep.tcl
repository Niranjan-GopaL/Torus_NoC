#!/usr/bin/env tclsh
# =============================================================================
# exp1_fifo_sweep.tcl — reference TCL for the Experiment 1 FIFO sweep
#
# NOTE: this is a single-shot reference. The production runner is
#   scripts/run_exp1_sweep.sh
# which edits torus_4x4.sv:22 with sed (works around the parameter-chain
# pitfall documented in docs/vivado_automation_commands.md §3).
#
# Run with:
#   source final/scripts/_env.sh
#   vivado -mode batch -source $TCL_DIR/exp1_fifo_sweep.tcl
#
# Reads from env (set by scripts/_env.sh):
#   PROJ_XPR        path to the .xpr file
#   RESULTS_FILE    docs/results.md
# =============================================================================

if {[info exists env(PROJ_XPR)]}     { set proj_path $env(PROJ_XPR) } \
    else { error "PROJ_XPR not set — source scripts/_env.sh first" }
if {[info exists env(RESULTS_FILE)]} { set results_file $env(RESULTS_FILE) } \
    else { error "RESULTS_FILE not set — source scripts/_env.sh first" }

open_project $proj_path

set fifo_depths {2 4 8 16 32 64}

puts "================================"
puts "Experiment 1: Custom Routing - FIFO Depth Sweep"
puts "================================"

set f [open $results_file a]
puts $f "\n\n# Experiment 1: Custom Routing - FIFO Depth Sweep (60000ns run)"
puts $f "| FIFO Depth | Cycles Taken | Notes |"
puts $f "|---|---|---|"
close $f

foreach depth $fifo_depths {
    puts "\nTesting FIFO_DEPTH=$depth..."
    set_property generic "FIFO_DEPTH=$depth" [get_filesets sim_1]
    launch_simulation -mode behavioral
    run 60000ns
    puts "Sim completed for FIFO_DEPTH=$depth"
    close_sim
}

puts "\n================================"
puts "All sims completed. Check results.md for output."
puts "================================"
exit
