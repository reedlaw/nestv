module nes_palette (
	input  logic [5:0]  color,
	output logic [23:0] rgb
);
	always_comb begin
		case (color)
			6'h00: rgb = 24'h545454; 6'h01: rgb = 24'h001e74;
			6'h02: rgb = 24'h081090; 6'h03: rgb = 24'h300088;
			6'h04: rgb = 24'h440064; 6'h05: rgb = 24'h5c0030;
			6'h06: rgb = 24'h540400; 6'h07: rgb = 24'h3c1800;
			6'h08: rgb = 24'h202a00; 6'h09: rgb = 24'h083a00;
			6'h0a: rgb = 24'h004000; 6'h0b: rgb = 24'h003c00;
			6'h0c: rgb = 24'h00323c; 6'h0d: rgb = 24'h000000;
			6'h0e: rgb = 24'h000000; 6'h0f: rgb = 24'h000000;
			6'h10: rgb = 24'h989698; 6'h11: rgb = 24'h084cc4;
			6'h12: rgb = 24'h3032ec; 6'h13: rgb = 24'h5c1ee4;
			6'h14: rgb = 24'h8814b0; 6'h15: rgb = 24'ha01464;
			6'h16: rgb = 24'h982220; 6'h17: rgb = 24'h783c00;
			6'h18: rgb = 24'h545a00; 6'h19: rgb = 24'h287200;
			6'h1a: rgb = 24'h087c00; 6'h1b: rgb = 24'h007628;
			6'h1c: rgb = 24'h006678; 6'h1d: rgb = 24'h000000;
			6'h1e: rgb = 24'h000000; 6'h1f: rgb = 24'h000000;
			6'h20: rgb = 24'heceeec; 6'h21: rgb = 24'h4c9aec;
			6'h22: rgb = 24'h787cec; 6'h23: rgb = 24'hb062ec;
			6'h24: rgb = 24'he454ec; 6'h25: rgb = 24'hec58b4;
			6'h26: rgb = 24'hec6a64; 6'h27: rgb = 24'hd48820;
			6'h28: rgb = 24'ha0aa00; 6'h29: rgb = 24'h74c400;
			6'h2a: rgb = 24'h4cd020; 6'h2b: rgb = 24'h38cc6c;
			6'h2c: rgb = 24'h38b4cc; 6'h2d: rgb = 24'h3c3c3c;
			6'h2e: rgb = 24'h000000; 6'h2f: rgb = 24'h000000;
			6'h30: rgb = 24'heceeec; 6'h31: rgb = 24'ha8ccec;
			6'h32: rgb = 24'hbcbcec; 6'h33: rgb = 24'hd4b2ec;
			6'h34: rgb = 24'hecaeec; 6'h35: rgb = 24'hecaed4;
			6'h36: rgb = 24'hecb4b0; 6'h37: rgb = 24'he4c490;
			6'h38: rgb = 24'hccd278; 6'h39: rgb = 24'hb4de78;
			6'h3a: rgb = 24'ha8e290; 6'h3b: rgb = 24'h98e2b4;
			6'h3c: rgb = 24'ha0d6e4; 6'h3d: rgb = 24'ha0a2a0;
			6'h3e: rgb = 24'h000000; 6'h3f: rgb = 24'h000000;
		endcase
	end
endmodule
