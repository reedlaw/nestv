// M0 synthesis harness. This is deliberately not the eventual board top:
// it retains the encoder datapath while keeping the unconstrained physical
// interface within the Primer 25K package's pin count.
module yc_out_synth_top (
	input  logic       clk,
	output logic [7:0] y,
	output logic [7:0] c
);
	logic [23:0] rgb = 24'h010101;
	logic [9:0] sample = 0;
	logic [23:0] yc;

	always_ff @(posedge clk) begin
		sample <= sample + 1'b1;
		rgb <= {rgb[22:0], rgb[23] ^ rgb[22] ^ rgb[21] ^ rgb[16]};
	end

	yc_out encoder (
		.clk,
		.PHASE_INC(40'h1555_5555_55),
		.PAL_EN(1'b0),
		.CVBS(1'b0),
		.COLORBURST_RANGE({7'd40, 10'd148}),
		.hsync(sample < 10'd64),
		.vsync(1'b0),
		.csync(sample < 10'd64),
		.de(sample >= 10'd128),
		.din(rgb),
		.dout(yc),
		.hsync_o(),
		.vsync_o(),
		.csync_o(),
		.de_o()
	);

	assign c = yc[23:16];
	assign y = yc[15:8];
endmodule
