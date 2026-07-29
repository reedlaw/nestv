set core rtl/core/nestang/src

set_device GW5A-LV25MG121NC1/I0 -device_version A
add_file "$core/boards/primer25k.v"
add_file rtl/platform/primer25k/nestv_primer25k_top.sv
add_file -type cst rtl/platform/primer25k/nestv_primer25k.cst
add_file -type sdc rtl/platform/primer25k/nestv_primer25k.sdc
add_file -type verilog "$core/plla/gowin_pll_27.v"
add_file -type verilog "build/gowin/primer25k/gowin_pll_hdmi_m3.v"
add_file -type verilog "$core/plla/gowin_pll_nes.v"
add_file -type verilog "$core/plla/pll_12.v"
add_file -type verilog "$core/usb_hid_host.v"
add_file -type verilog "$core/iosys/iosys_bl616.v"
add_file -type verilog "$core/iosys/gowin_dpb_menu.v"
add_file -type verilog "$core/iosys/textdisp.v"
add_file -type verilog "$core/iosys/uart_fixed.v"

foreach file [glob \
	"$core/*.v" "$core/*.sv" \
	"$core/hdmi2/*.sv" \
	"$core/mappers/*.v" "$core/mappers/*.sv" \
	"$core/t65/*.v"] {
	if {![string match "*/game_data.v" $file] &&
	    ![string match "*/hw_uart.v" $file] &&
	    ![string match "*/print.v" $file] &&
	    ![string match "*/usb_hid_host.v" $file]} {
		add_file -type verilog $file
	}
}

add_file build/upstream/yc_out.sv
add_file rtl/video/nes_palette.sv
add_file rtl/video/nestang_video_adapter.sv
add_file rtl/video/video_dac_quantizer.sv

set_option -synthesis_tool gowinsynthesis
set_option -top_module nestv_primer25k_top
set_option -verilog_std sysv2017
set_option -rw_check_on_ram 1
set_option -use_mspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -multi_boot 1
set_option -place_option 2
set_option -output_base_name nestv_primer25k_m3

run all
