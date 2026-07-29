# M0 encoder target: approximately twice the NTSC NES master clock.
create_clock -name encoder_clk -period 23.280 [get_ports {clk}]
