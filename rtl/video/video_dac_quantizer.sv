module video_dac_quantizer (
	input  logic [7:0] y_in,
	input  logic [7:0] c_in,
	input  logic       csync,
	output logic [5:0] y_out,
	output logic [5:0] c_out
);
	logic [13:0] y_scaled;

	always_comb begin
		// 6-bit studio-range composite levels:
		// sync tip = 0, blank/black = 19, peak white = 63.
		y_scaled = (y_in * 6'd45) >> 8;
		y_out = csync ? 6'd0 : 6'(6'd19 + y_scaled[5:0]);

		// Chroma is centered on code 32 and is AC-coupled by the analog stage.
		c_out = c_in[7:2];
	end
endmodule
