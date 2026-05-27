# =============================================================================
# create_project.tcl — Recreates the Vivado project from scratch
#
# Recommended invocation (path config inherited from scripts/_env.sh):
#   source final/scripts/_env.sh
#   vivado -mode batch -source $TCL_DIR/create_project.tcl
#
# Project layout reproduced:
#   Part      : xc7a200tfbg676-2
#   Board     : xilinx.com:ac701:part0:1.4
#   sources_1 : src/router_fifo.sv, src/torus_4x4.sv          (top: torus_4x4)
#   sim_1     : src/tb/tb_torus_large.sv,
#               src/tb/tb_different_workload.sv
#               (default top: tb_torus_4x4_random_bp_10k for Experiment 1)
#
# Paths read from environment (set by scripts/_env.sh):
#   VIVADO_PROJECTS_DIR  parent dir under which the .xpr is created
#   PROJ_NAME            project name + sub-directory name
#   ROOT_DIR             final/  (project root)
#
# Falls back to script-relative resolution if the env vars are missing, so
# you can still run `vivado -source create_project.tcl` standalone.
# =============================================================================

# Resolve final/ from this script's location as a fallback
set this_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize "$this_dir/.."]

# Read overrides from environment when available
if {[info exists env(ROOT_DIR)]}            { set root_dir $env(ROOT_DIR) }
if {[info exists env(PROJ_NAME)]}           { set proj_name $env(PROJ_NAME) } \
    else                                    { set proj_name "Torus_4x4_extensive_tests" }
if {[info exists env(VIVADO_PROJECTS_DIR)]} { set proj_dir $env(VIVADO_PROJECTS_DIR) } \
    else                                    { set proj_dir [file join $::env(HOME) "vivado_projects"] }

set src_dir "$root_dir/src"
set tb_dir  "$root_dir/src/tb"

# Ensure parent directory exists
file mkdir $proj_dir

# Create the project (force-overwrites if it already exists)
create_project $proj_name $proj_dir/$proj_name -part xc7a200tfbg676-2 -force

# Board + default library
set_property board_part xilinx.com:ac701:part0:1.4 [current_project]
set_property default_lib xil_defaultlib [current_project]

# Design sources
add_files -norecurse [list \
    $src_dir/router_fifo.sv \
    $src_dir/torus_4x4.sv \
]
set_property top torus_4x4 [get_filesets sources_1]

# Simulation sources
add_files -fileset sim_1 -norecurse [list \
    $tb_dir/tb_torus_large.sv \
    $tb_dir/tb_different_workload.sv \
]
set_property top tb_torus_4x4_random_bp_10k [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts ""
puts "================================================="
puts "Project created at : $proj_dir/$proj_name"
puts "Design top         : torus_4x4"
puts "Sim top            : tb_torus_4x4_random_bp_10k"
puts "================================================="

close_project
exit
