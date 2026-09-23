# Vivado TCL Project Generator
# Target Device: Xilinx Zynq-7000 (XC7Z020, Speed Grade -2: xc7z020clg400-2)
# Usage:
#   vivado -mode batch -source HDL/scripts/create_vivado_projects.tcl

set origin_dir [file normalize [file join [file dirname [info script]] "../.."]]
set part_name "xc7z020clg400-2"

puts "=========================================================="
puts " Creating Vivado Projects for Zynq-7020 (-2 Speed Grade)"
puts " Root Directory: $origin_dir"
puts " Target Part:    $part_name"
puts "=========================================================="

# -------------------------------------------------------------
# 1. Project 1: Catmull-Rom Cubic Resampler
# -------------------------------------------------------------
set catmull_proj_dir "$origin_dir/vivado_catmull"
create_project -force proj_cubic_catmull $catmull_proj_dir -part $part_name

# Add RTL sources
add_files -norecurse "$origin_dir/HDL/cubic_catmull/cubic_catmull_core.vhd"
add_files -norecurse "$origin_dir/HDL/cubic_catmull/resampler_cubic_catmull.vhd"
set_property file_type {VHDL} [get_files "$origin_dir/HDL/cubic_catmull/cubic_catmull_core.vhd"]
set_property file_type {VHDL} [get_files "$origin_dir/HDL/cubic_catmull/resampler_cubic_catmull.vhd"]
set_property top resampler_cubic_catmull [current_fileset]

# Add Constraints
add_files -fileset constrs_1 -norecurse "$origin_dir/HDL/constraints/timing.xdc"

# Add Simulation Testbench
add_files -fileset sim_1 -norecurse "$origin_dir/HDL/cubic_catmull/tb_cubic_catmull.vhd"
set_property file_type {VHDL} [get_files "$origin_dir/HDL/cubic_catmull/tb_cubic_catmull.vhd"]
set_property top tb_cubic_catmull [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "Catmull-Rom project generated in $catmull_proj_dir"

# -------------------------------------------------------------
# 2. Project 2: Lagrange 4-Point Cubic Resampler
# -------------------------------------------------------------
set lagrange_proj_dir "$origin_dir/vivado_lagrange"
create_project -force proj_cubic_lagrange $lagrange_proj_dir -part $part_name

# Add RTL sources
add_files -norecurse "$origin_dir/HDL/cubic_lagrange/cubic_lagrange_core.vhd"
add_files -norecurse "$origin_dir/HDL/cubic_lagrange/resampler_cubic_lagrange.vhd"
set_property file_type {VHDL} [get_files "$origin_dir/HDL/cubic_lagrange/cubic_lagrange_core.vhd"]
set_property file_type {VHDL} [get_files "$origin_dir/HDL/cubic_lagrange/resampler_cubic_lagrange.vhd"]
set_property top resampler_cubic_lagrange [current_fileset]

# Add Constraints
add_files -fileset constrs_1 -norecurse "$origin_dir/HDL/constraints/timing.xdc"

# Add Simulation Testbench
add_files -fileset sim_1 -norecurse "$origin_dir/HDL/cubic_lagrange/tb_cubic_interpolator.vhd"
set_property file_type {VHDL} [get_files "$origin_dir/HDL/cubic_lagrange/tb_cubic_interpolator.vhd"]
set_property top tb_cubic_interpolator [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "Lagrange project generated in $lagrange_proj_dir"
puts "=========================================================="
puts " Both Vivado projects successfully created!"
puts "=========================================================="

