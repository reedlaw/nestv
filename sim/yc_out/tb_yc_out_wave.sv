`timescale 1ns/1ps

module tb_yc_out_wave;
	import test_patterns::*;

	localparam int H_TOTAL = 2730;
	localparam int H_SYNC = 202;
	localparam int H_ACTIVE_START = 468;
	localparam int H_ACTIVE = 2112;

	logic clk = 0;
	logic hsync = 1;
	logic vsync = 0;
	logic csync = 1;
	logic de = 0;
	logic [23:0] din = 0;
	wire [23:0] dout;
	wire hsync_o;
	wire vsync_o;
	wire csync_o;
	wire de_o;
	string wave_path;

	always #5 clk = ~clk;

	yc_out dut (
		.clk,
		.PHASE_INC(40'h1555_5555_55),
		.PAL_EN(1'b0),
		.CVBS(1'b0),
		.COLORBURST_RANGE({7'd40, 10'd148}),
		.hsync,
		.vsync,
		.csync,
		.de,
		.din,
		.dout,
		.hsync_o,
		.vsync_o,
		.csync_o,
		.de_o
	);

	initial begin
		if (!$value$plusargs("WAVE=%s", wave_path))
			wave_path = "yc_out.fst";
		$dumpfile(wave_path);
		$dumpvars(0, tb_yc_out_wave);

		for (int line = 0; line < 3; line++) begin
			for (int sample = 0; sample < H_TOTAL; sample++) begin
				@(negedge clk);
				hsync = sample < H_SYNC;
				vsync = line == 0 && sample < H_SYNC;
				csync = hsync | vsync;
				de = sample >= H_ACTIVE_START &&
					sample < H_ACTIVE_START + H_ACTIVE;
				if (de) begin
					case (line)
						0: din = pattern_rgb(sample - H_ACTIVE_START, 0, H_ACTIVE);
						1: din = pattern_rgb(sample - H_ACTIVE_START, 70, H_ACTIVE);
						default: din = pattern_rgb(sample - H_ACTIVE_START, 130, H_ACTIVE);
					endcase
				end else begin
					din = 24'h000000;
				end
			end
		end

		repeat (12) @(negedge clk);
		$display("PASS: wrote waveform to %s", wave_path);
		$finish;
	end
endmodule
