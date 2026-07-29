`timescale 1ns/1ps

module tb_yc_out;
	logic clk = 0;
	logic [39:0] phase_inc = 40'h1555_5555_55;
	logic pal_en = 0;
	logic cvbs = 0;
	logic [16:0] colorburst_range = {7'd40, 10'd148};
	logic hsync = 0;
	logic vsync = 0;
	logic csync = 0;
	logic de = 0;
	logic [23:0] din = 0;
	wire [23:0] dout;
	wire hsync_o;
	wire vsync_o;
	wire csync_o;
	wire de_o;

	int errors = 0;
	int cycles = 0;
	logic [4:0] hsync_history = 0;
	logic [4:0] vsync_history = 0;
	logic [4:0] csync_history = 0;
	logic [4:0] de_history = 0;

	always #5 clk = ~clk;

	yc_out dut (
		.clk,
		.PHASE_INC(phase_inc),
		.PAL_EN(pal_en),
		.CVBS(cvbs),
		.COLORBURST_RANGE(colorburst_range),
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

	always @(posedge clk) begin
		cycles <= cycles + 1;
		hsync_history <= {hsync_history[3:0], hsync};
		vsync_history <= {vsync_history[3:0], vsync};
		csync_history <= {csync_history[3:0], csync};
		de_history <= {de_history[3:0], de};

		if (cycles > 12) begin
			if (hsync_o !== hsync_history[4]) errors <= errors + 1;
			if (vsync_o !== vsync_history[4]) errors <= errors + 1;
			if (csync_o !== csync_history[4]) errors <= errors + 1;
			if (de_o !== de_history[4]) errors <= errors + 1;
		end
	end

	task automatic drive(
		input logic [23:0] rgb,
		input logic active,
		input logic hs,
		input logic vs,
		input logic cs
	);
		@(negedge clk);
		din = rgb;
		de = active;
		hsync = hs;
		vsync = vs;
		csync = cs;
	endtask

	initial begin
		repeat (16) drive(24'h000000, 0, 1, 0, 1);
		repeat (24) drive(24'h000000, 0, 0, 0, 0);
		repeat (32) drive(24'hffffff, 1, 0, 0, 0);
		repeat (32) drive(24'hff0000, 1, 0, 0, 0);
		repeat (32) drive(24'h00ff00, 1, 0, 0, 0);
		repeat (32) drive(24'h0000ff, 1, 0, 0, 0);
		repeat (16) drive(24'h000000, 0, 0, 1, 1);
		repeat (16) drive(24'h000000, 0, 0, 0, 0);

		if (errors != 0)
			$fatal(1, "yc_out control alignment failed with %0d errors", errors);
		if ($isunknown(dout))
			$fatal(1, "yc_out contains unknown output values after warmup");

		$display("PASS: yc_out standalone smoke test (%0d cycles)", cycles);
		$finish;
	end
endmodule
