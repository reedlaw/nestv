`timescale 1ns/1ps

module tb_nestang_video_adapter;
	logic clk = 0;
	logic [5:0] color = 0;
	logic [8:0] cycle = 0;
	logic [8:0] scanline = 0;
	logic overlay = 0;
	logic [14:0] overlay_color = 0;
	logic [7:0] overlay_x, overlay_y;
	logic native_de, native_hsync, native_vsync, native_csync;
	logic [23:0] hdmi_rgb, yc_rgb, yc_encoded;
	logic yc_hsync, yc_vsync, yc_csync, yc_de;
	integer i;

	always #11.64 clk = ~clk; // 42.954544 MHz, 2x NESTang's NES master clock

	nestang_video_adapter dut (.*);

	task automatic check_split;
		@(posedge clk);
		#1;
		assert (hdmi_rgb === yc_rgb)
			else $fatal(1, "video branches differ: %h != %h", hdmi_rgb, yc_rgb);
	endtask

	initial begin
		// Every palette entry reaches both branches without a framebuffer.
		cycle = 9'd20;
		scanline = 9'd20;
		for (i = 0; i < 64; i = i + 1) begin
			color = i[5:0];
			check_split();
		end
		assert (hdmi_rgb == 24'h000000); // palette entry 63

		// The shared pre-split overlay uses NESTang's BGR5 convention.
		overlay = 1;
		overlay_color = {5'h03, 5'h0c, 5'h1f};
		check_split();
		assert (hdmi_rgb == 24'hff6318)
			else $fatal(1, "bad overlay expansion: %h", hdmi_rgb);
		assert (overlay_x == 8'd20 && overlay_y == 8'd20);

		// Blanking and sync are derived directly from the PPU raster.
		overlay = 0;
		cycle = 9'd255; scanline = 9'd239; check_split();
		assert (native_de && !native_hsync && !native_vsync);
		cycle = 9'd256; check_split();
		assert (!native_de && hdmi_rgb == 0);
		cycle = 9'd280; check_split();
		assert (native_hsync && native_csync);
		cycle = 9'd305; check_split();
		assert (!native_hsync);
		cycle = 9'd10; scanline = 9'd241; check_split();
		assert (native_vsync && native_csync && !native_de);
		scanline = 9'd244; check_split();
		assert (!native_vsync);

		// Exercise the encoder pipeline and ensure it never sees X data.
		color = 6'h21;
		cycle = 9'd30;
		scanline = 9'd30;
		repeat (32) @(posedge clk);
		assert (!$isunknown(yc_encoded));

		$display("PASS: shared native HDMI/Y-C path, overlay, blanking, and sync");
		$finish;
	end
endmodule
