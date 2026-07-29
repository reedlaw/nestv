# Reproducible Gowin synthesis entry point for the standalone encoder.
# Run via `make synth-primer25k` with Gowin EDA 1.9.12.03.

set_device -name GW5A-25A GW5A-LV25MG121NC1/I0
set_option -top_module yc_out_synth_top
set_option -verilog_std sysv2017
set_option -output_base_name yc_out_primer25k

add_file build/upstream/yc_out.sv
add_file rtl/platform/primer25k/yc_out_synth_top.sv
add_file rtl/platform/primer25k/yc_out_primer25k.cst
add_file rtl/platform/primer25k/timing.sdc

run all
