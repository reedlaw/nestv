// Native NESTang video fan-out. The analog branch never reads the HDMI
// framebuffer: both consumers receive the same palette/overlay result here.
module nestang_video_adapter (
	input  logic        clk,
	input  logic [5:0]  color,
	input  logic [8:0]  cycle,
	input  logic [8:0]  scanline,
	input  logic        overlay,
	input  logic [14:0] overlay_color, // BGR5, matching NESTang iosys
	output logic [7:0]  overlay_x,
	output logic [7:0]  overlay_y,
	output logic        native_de,
	output logic        native_hsync,
	output logic        native_vsync,
	output logic        native_csync,
	output logic [23:0] hdmi_rgb,
	output logic [23:0] yc_rgb,
	output logic [23:0] yc_encoded,
	output logic        yc_hsync,
	output logic        yc_vsync,
	output logic        yc_csync,
	output logic        yc_de
);
	logic [23:0] palette_rgb;
	logic [23:0] overlay_rgb;

	nes_palette palette (
		.color(color),
		.rgb(palette_rgb)
	);

	// NESTang's native raster is 341 PPU dots by 262 scanlines. Sync is
	// active-high because yc_out uses the asserted level to reset its burst
	// timer. Twenty-five dots produce a 4.66 us horizontal pulse.
	always_comb begin
		overlay_x    = cycle[7:0];
		overlay_y    = scanline[7:0];
		native_de    = (cycle < 9'd256) && (scanline < 9'd240);
		native_hsync = (cycle >= 9'd280) && (cycle < 9'd305);
		native_vsync = (scanline >= 9'd241) && (scanline < 9'd244);
		native_csync = native_hsync | native_vsync;

		overlay_rgb = {
			overlay_color[4:0], overlay_color[4:2],
			overlay_color[9:5], overlay_color[9:7],
			overlay_color[14:10], overlay_color[14:12]
		};
		hdmi_rgb = native_de ? (overlay ? overlay_rgb : palette_rgb) : 24'h000000;
		yc_rgb = hdmi_rgb;
	end

	yc_out encoder (
		.clk(clk),
		.PHASE_INC(40'h1555_5555_55),
		.PAL_EN(1'b0),
		.CVBS(1'b0),
		.COLORBURST_RANGE({7'd40, 10'd148}),
		.hsync(native_hsync),
		.vsync(native_vsync),
		.csync(native_csync),
		.de(native_de),
		.din(yc_rgb),
		.dout(yc_encoded),
		.hsync_o(yc_hsync),
		.vsync_o(yc_vsync),
		.csync_o(yc_csync),
		.de_o(yc_de)
	);
endmodule
