module nestv_primer25k_top (
	input  logic        sys_clk,
	input  logic        s1,
	input  logic        UART_RXD,
	output logic        UART_TXD,
	output logic        O_sdram_clk,
	output logic        O_sdram_cke,
	output logic        O_sdram_cs_n,
	output logic        O_sdram_cas_n,
	output logic        O_sdram_ras_n,
	output logic        O_sdram_wen_n,
	inout  wire  [15:0] IO_sdram_dq,
	output logic [12:0] O_sdram_addr,
	output logic [1:0]  O_sdram_ba,
	output logic [1:0]  O_sdram_dqm,
	output logic        tmds_clk_n,
	output logic        tmds_clk_p,
	output logic [2:0]  tmds_d_n,
	output logic [2:0]  tmds_d_p,
	output logic [5:0]  video_y,
	output logic [5:0]  video_c
);
	logic [7:0] unused_led;
	wire unused_usb_dp;
	wire unused_usb_dn;
	logic unused_ds_clk, unused_ds_mosi, unused_ds_cs;
	logic unused_ds_clk2, unused_ds_mosi2, unused_ds_cs2;

	nestang_top core (
		.sys_clk,
		.s1,
		.reset2(1'b0),
		.UART_RXD,
		.UART_TXD,
		.O_sdram_clk,
		.O_sdram_cke,
		.O_sdram_cs_n,
		.O_sdram_cas_n,
		.O_sdram_ras_n,
		.O_sdram_wen_n,
		.IO_sdram_dq,
		.O_sdram_addr,
		.O_sdram_ba,
		.O_sdram_dqm,
		.led(unused_led),
		.ds_clk(unused_ds_clk),
		.ds_miso(1'b1),
		.ds_mosi(unused_ds_mosi),
		.ds_cs(unused_ds_cs),
		.ds_clk2(unused_ds_clk2),
		.ds_miso2(1'b1),
		.ds_mosi2(unused_ds_mosi2),
		.ds_cs2(unused_ds_cs2),
		.usb1_dp(unused_usb_dp),
		.usb1_dn(unused_usb_dn),
		.tmds_clk_n,
		.tmds_clk_p,
		.tmds_d_n,
		.tmds_d_p
	);

	logic [23:0] hdmi_rgb;
	logic [23:0] yc_rgb;
	logic [23:0] yc_encoded;

	// The existing SDRAM PLL supplies 3x the 21.477272 MHz NES master clock.
	// At 64.431816 MHz, NTSC color carrier is exactly clk/18.
	nestang_video_adapter #(
		.PHASE_INC(40'h0e38_e38e_39),
		.BURST_START(7'd60),
		.BURST_END(10'd222)
	) native_video (
		.clk(core.fclk),
		.color(core.color),
		.cycle(core.cycle),
		.scanline(core.scanline),
		.overlay(core.overlay),
		.overlay_color(core.overlay_color),
		.overlay_x(),
		.overlay_y(),
		.native_de(),
		.native_hsync(),
		.native_vsync(),
		.native_csync(),
		.hdmi_rgb,
		.yc_rgb,
		.yc_encoded,
		.yc_hsync(),
		.yc_vsync(),
		.yc_csync(),
		.yc_de()
	);

	assign video_y = yc_encoded[15:10];
	assign video_c = yc_encoded[23:18];
endmodule
