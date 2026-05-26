# =============================================================================
# create_project.tcl — Recreates the Torus_4x4_extensive_tests Vivado project
#
# Run with:
#   vivado -mode batch -source create_project.tcl
#
# This reproduces the original project layout:
#   Part:    xc7a200tfbg676-2
#   Board:   xilinx.com:ac701:part0:1.4
#   sources_1: router_fifo.sv, torus_4x4.sv   (top: torus_4x4)
#   sim_1:     tb_torus_large.sv, tb_different_workload.sv
#              (default top: tb_torus_4x4_random_bp_10k for Experiment 1)
# =============================================================================

set proj_name    "Torus_4x4_extensive_tests"
set proj_dir     "/home/nira/Documents/code/ece/rtl"
set src_dir      "/home/nira/Documents/code/swe/claude_code_project/noc_project/final"

# -- Create project (--force overwrites if exists)
create_project $proj_name $proj_dir/$proj_name -part xc7a200tfbg676-2 -force

# -- Set board
set_property board_part xilinx.com:ac701:part0:1.4 [current_project]

# -- Set default library
set_property default_lib xil_defaultlib [current_project]

# -- Add design sources
add_files -norecurse [list \
    $src_dir/router_fifo.sv \
    $src_dir/torus_4x4.sv \
]

# -- Set the design top
set_property top torus_4x4 [get_filesets sources_1]

# -- Add simulation sources
add_files -fileset sim_1 -norecurse [list \
    $src_dir/tb_torus_large.sv \
    $src_dir/tb_different_workload.sv \
]

# -- Set the simulation top (Experiment 1)
set_property top tb_torus_4x4_random_bp_10k [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# -- Save & close
puts ""
puts "================================================="
puts "Project created at: $proj_dir/$proj_name"
puts "Design top      : torus_4x4"
puts "Sim top         : tb_torus_4x4_random_bp_10k"
puts "================================================="

close_project
exit
