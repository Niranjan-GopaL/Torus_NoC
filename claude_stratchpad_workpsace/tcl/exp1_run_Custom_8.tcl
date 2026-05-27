open_project {/home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests/Torus_4x4_extensive_tests.xpr}
set_property generic {} [get_filesets sim_1]
set_property top tb_torus_4x4_random_bp_10k [get_filesets sim_1]
launch_simulation -mode behavioral
run 60000ns
close_sim
exit
