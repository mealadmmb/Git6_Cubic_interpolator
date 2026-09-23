read_vhdl -vhdl2008 "HDL/cubic_catmull/cubic_catmull_core.vhd"
read_vhdl -vhdl2008 "HDL/cubic_catmull/resampler_cubic_catmull.vhd"
read_xdc "HDL/constraints/timing.xdc"
synth_design -top resampler_cubic_catmull -part xc7z020clg400-2
report_timing_summary

