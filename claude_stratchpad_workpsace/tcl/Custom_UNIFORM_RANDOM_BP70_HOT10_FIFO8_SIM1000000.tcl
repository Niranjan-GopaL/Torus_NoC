open_project {/home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests/Torus_4x4_extensive_tests.xpr}
set_property generic {} [get_filesets sim_1]
set_property top tb_noc_workload_comparison [get_filesets sim_1]
launch_simulation -mode behavioral
run 1000000ns
close_sim
exit
