`timescale 1ns/1ps

module tb_yc_out_export;
	import test_patterns::*;

	localparam int H_TOTAL = 2730;
	localparam int H_SYNC = 202;
	localparam int H_ACTIVE_START = 468;
	localparam int H_ACTIVE = 2112;
	localparam int V_TOTAL = 262;
	localparam int V_ACTIVE_START = 20;
	localparam int V_ACTIVE = 240;
	localparam int LATENCY = 5;

	logic clk = 0;
	logic hsync = 1;
	logic vsync = 1;
	logic csync = 1;
	logic de = 0;
	logic [23:0] din = 0;
	wire [23:0] dout;
	wire hsync_o;
	wire vsync_o;
	wire csync_o;
	wire de_o;

	int unsigned q_line [0:LATENCY];
	int unsigned q_sample [0:LATENCY];
	logic [23:0] q_rgb [0:LATENCY];
	integer output_file;
	string output_path;

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

	always_ff @(posedge clk) begin
		q_line[0] <= q_line[0];
		q_sample[0] <= q_sample[0];
		q_rgb[0] <= din;
		for (int i = 1; i <= LATENCY; i++) begin
			q_line[i] <= q_line[i - 1];
			q_sample[i] <= q_sample[i - 1];
			q_rgb[i] <= q_rgb[i - 1];
		end
	end

	initial begin
		if (!$value$plusargs("OUTPUT=%s", output_path))
			output_path = "yc_out.csv";
		output_file = $fopen(output_path, "w");
		if (output_file == 0)
			$fatal(1, "unable to open %s", output_path);
		$fwrite(output_file, "line,sample,de,hsync,vsync,csync,r,g,b,y,c\n");

		for (int line = 0; line < V_TOTAL; line++) begin
			for (int sample = 0; sample < H_TOTAL; sample++) begin
				@(negedge clk);
				if (line > 0)
					$fwrite(output_file,
						"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
						q_line[LATENCY], q_sample[LATENCY], de_o,
						hsync_o, vsync_o, csync_o,
						q_rgb[LATENCY][23:16], q_rgb[LATENCY][15:8],
						q_rgb[LATENCY][7:0], dout[15:8], dout[23:16]);

				q_line[0] = line;
				q_sample[0] = sample;
				hsync = sample < H_SYNC;
				vsync = line < 3;
				csync = hsync | vsync;
				de = line >= V_ACTIVE_START &&
					line < V_ACTIVE_START + V_ACTIVE &&
					sample >= H_ACTIVE_START &&
					sample < H_ACTIVE_START + H_ACTIVE;
				if (de)
					din = pattern_rgb(sample - H_ACTIVE_START,
						line - V_ACTIVE_START, H_ACTIVE);
				else
					din = 24'h000000;
			end
		end

		$fclose(output_file);
		$display("PASS: exported %0d raster samples to %s",
			H_TOTAL * (V_TOTAL - 1), output_path);
		$finish;
	end
endmodule
