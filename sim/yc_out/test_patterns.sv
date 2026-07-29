package test_patterns;
	function automatic logic [23:0] nes_palette(input logic [5:0] index);
		logic [23:0] palette [0:63];
		begin
			palette = '{
				24'h626262, 24'h001fb2, 24'h2404c8, 24'h5200b2,
				24'h730076, 24'h800024, 24'h730b00, 24'h522800,
				24'h244400, 24'h005700, 24'h005c00, 24'h005324,
				24'h003c76, 24'h000000, 24'h000000, 24'h000000,
				24'hababab, 24'h0d57ff, 24'h4b30ff, 24'h8a13ff,
				24'hbc08d6, 24'hd21269, 24'hc72e00, 24'h9d5400,
				24'h607b00, 24'h209800, 24'h00a300, 24'h009942,
				24'h007db4, 24'h000000, 24'h000000, 24'h000000,
				24'hffffff, 24'h53aeff, 24'h9085ff, 24'hd365ff,
				24'hff57ff, 24'hff5dcf, 24'hff7757, 24'hfa9e00,
				24'hbdc700, 24'h7ae700, 24'h43f611, 24'h26ef7e,
				24'h2cd5f6, 24'h4e4e4e, 24'h000000, 24'h000000,
				24'hffffff, 24'hb6e1ff, 24'hced1ff, 24'he9c3ff,
				24'hffbcff, 24'hffbdf4, 24'hffc6c3, 24'hffd59a,
				24'he9e681, 24'hcef481, 24'hb6fb9a, 24'ha9fac3,
				24'ha9f0f4, 24'hb8b8b8, 24'h000000, 24'h000000
			};
			nes_palette = palette[index];
		end
	endfunction

	function automatic logic [23:0] pattern_rgb(
		input int unsigned x,
		input int unsigned y,
		input int unsigned width
	);
		int unsigned band;
		int unsigned level;
		int unsigned palette_index;
		begin
			if (y < 60) begin
				band = (x * 8) / width;
				case (band)
					0: pattern_rgb = 24'hffffff;
					1: pattern_rgb = 24'hffff00;
					2: pattern_rgb = 24'h00ffff;
					3: pattern_rgb = 24'h00ff00;
					4: pattern_rgb = 24'hff00ff;
					5: pattern_rgb = 24'hff0000;
					6: pattern_rgb = 24'h0000ff;
					default: pattern_rgb = 24'h000000;
				endcase
			end else if (y < 120) begin
				level = (x * 255) / (width - 1);
				pattern_rgb = {level[7:0], level[7:0], level[7:0]};
			end else if (y < 180) begin
				palette_index = (((y - 120) / 15) * 16) + ((x * 16) / width);
				pattern_rgb = nes_palette(palette_index[5:0]);
			end else if (y < 210) begin
				pattern_rgb = x[0] ? 24'hffffff : 24'h000000;
			end else begin
				pattern_rgb = (x[3] ^ y[3]) ? 24'hff2020 : 24'h2040ff;
			end
		end
	endfunction
endpackage
