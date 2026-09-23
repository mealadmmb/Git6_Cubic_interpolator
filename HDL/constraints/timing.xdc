# Timing constraints for 100 MHz clock on Zynq-7020 (-2 speed grade)
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Input delay constraints (virtual)
set_input_delay -clock [get_clocks clk] -min 1.0 [get_ports {rst_n phase_step* in_valid in_i* in_q*}]
set_input_delay -clock [get_clocks clk] -max 2.5 [get_ports {rst_n phase_step* in_valid in_i* in_q*}]

# Output delay constraints (virtual)
set_output_delay -clock [get_clocks clk] -min 1.0 [get_ports {in_ready out_valid out_i* out_q*}]
set_output_delay -clock [get_clocks clk] -max 2.5 [get_ports {in_ready out_valid out_i* out_q*}]
