`timescale 1ns/1ps

module tb_video_dac_quantizer;
	logic [7:0] y_in;
	logic [7:0] c_in;
	logic csync;
	logic [5:0] y_out;
	logic [5:0] c_out;

	video_dac_quantizer dut (.*);

	initial begin
		csync = 1;
		y_in = 8'hff;
		c_in = 8'h80;
		#1;
		assert (y_out == 0);
		assert (c_out == 32);

		csync = 0;
		y_in = 0;
		#1;
		assert (y_out == 19);

		y_in = 8'hff;
		#1;
		assert (y_out == 63);

		y_in = 8'h80;
		c_in = 8'h00;
		#1;
		assert (y_out > 19 && y_out < 63);
		assert (c_out == 0);

		c_in = 8'hff;
		#1;
		assert (c_out == 63);

		$display("PASS: six-bit DAC sync, luma, and chroma mapping");
		$finish;
	end
endmodule
