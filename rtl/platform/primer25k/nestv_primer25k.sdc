create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
create_clock -name fclk -period 15.510 [get_nets {core/fclk}]
create_generated_clock -name clk -source [get_nets {core/fclk}] -divide_by 3 [get_nets {core/clk}]
create_clock -name hclk5 -period 2.694 [get_nets {core/hclk5}]

# The NESTang NES and SDRAM clocks are synchronous outputs of pll_nes.
# Its SDRAM interface intentionally budgets three fclk cycles outbound and
# two fclk cycles inbound; preserve the upstream multicycle constraints.
set_multicycle_path 3 -end -setup -from [get_clocks {clk}] -to [get_clocks {fclk}]
set_multicycle_path 2 -end -hold -from [get_clocks {clk}] -to [get_clocks {fclk}]
set_multicycle_path 2 -start -setup -from [get_clocks {fclk}] -to [get_clocks {clk}]
set_multicycle_path 1 -start -hold -from [get_clocks {fclk}] -to [get_clocks {clk}]
