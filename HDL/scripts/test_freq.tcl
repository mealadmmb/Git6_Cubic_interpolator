read_vhdl -vhdl2008 "HDL/cubic_catmull/cubic_catmull_core.vhd"
read_vhdl -vhdl2008 "HDL/cubic_catmull/resampler_cubic_catmull.vhd"
synth_design -top resampler_cubic_catmull -part xc7z020clg400-2 -mode out_of_context
create_clock -period 6.666 -name clk [get_ports clk]
opt_design
place_design
route_design
report_timing_summary -file "sim_data/timing_150mhz.rpt"

