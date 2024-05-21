module SDLoader (
	clk,
	resetn,
	overlay,
	color,
	scanline,
	cycle,
	nes_btn,
	dout,
	dout_valid,
	sd_clk,
	sd_cmd,
	sd_dat0,
	sd_dat1,
	sd_dat2,
	sd_dat3,
	debug_reg,
	debug_out
);
	parameter FREQ = 27000000;
	input clk;
	input resetn;
	output reg overlay;
	output reg [5:0] color;
	output reg [7:0] scanline;
	output reg [7:0] cycle;
	input [7:0] nes_btn;
	output wire [7:0] dout;
	output wire dout_valid;
	output wire sd_clk;
	inout sd_cmd;
	input sd_dat0;
	output wire sd_dat1;
	output wire sd_dat2;
	output wire sd_dat3;
	input [7:0] debug_reg;
	output reg [7:0] debug_out;
	localparam [8191:0] FONT = 8192'h183c3c1818001800363600000000000036367f367f3636000c3e031e301f0c00006333180c6663001c361c6e3b336e000606030000000000180c0606060c1800060c1818180c060000663cff3c660000000c0c3f0c0c000000000000000c0c060000003f0000000000000000000c0c006030180c060301003e63737b6f673e000c0e0c0c0c0c3f001e33301c06333f001e33301c30331e00383c36337f3078003f031f3030331e001c06031f33331e003f3330180c0c0c001e33331e33331e001e33333e30180e00000c0c00000c0c00000c0c00000c0c06180c0603060c180000003f00003f0000060c1830180c06001e3330180c000c003e637b7b7b031e000c1e33333f3333003f66663e66663f003c66030303663c001f36666666361f007f46161e16467f007f46161e16060f003c66030373667c003333333f333333001e0c0c0c0c0c1e007830303033331e006766361e366667000f06060646667f0063777f7f6b63630063676f7b736363001c36636363361c003f66663e06060f001e3333333b1e38003f66663e366667001e33070e38331e003f2d0c0c0c0c1e003333333333333f0033333333331e0c006363636b7f7763006363361c1c3663003333331e0c0c1e007f6331184c667f001e06060606061e0003060c18306040001e18181818181e00081c36630000000000000000000000ff0c0c18000000000000001e303e336e000706063e66663b0000001e3303331e003830303e33336e0000001e333f031e001c36060f06060f0000006e33333e301f0706366e666667000c000e0c0c0c1e00300030303033331e070666361e3667000e0c0c0c0c0c1e000000337f7f6b630000001f333333330000001e3333331e0000003b66663e060f00006e33333e307800003b6e66060f0000003e031e301f00080c3e0c0c2c18000000333333336e0000003333331e0c000000636b7f7f3600000063361c36630000003333333e301f00003f190c263f00380c0c070c0c38001818180018181800070c0c380c0c07006e3b0000000000000000000000000000;
	localparam [5:0] COLOR_BACK = 13;
	localparam [5:0] COLOR_CURSOR = 55;
	localparam [5:0] COLOR_TEXT = 56;
	reg [4:0] active;
	reg [11:0] file_total;
	reg [11:0] file_start = 1;
	wire [4:0] total = (file_total < file_start ? 0 : (file_total >= (file_start + 19) ? 20 : (file_total - file_start) + 1));
	reg [4:0] cursor_now;
	reg [5:0] cursor_dot;
	localparam [63:0] CURSOR = 64'b0000000000000011000011110011111111111111001111110000111100000011;
	wire debug_active;
	assign debug_active = active;
	reg [2:0] pad;
	localparam [2:0] PAD_CENTER = 3'd0;
	localparam [2:0] PAD_UP = 3'd1;
	localparam [2:0] PAD_DOWN = 3'd2;
	localparam [2:0] PAD_LEFT = 3'd3;
	localparam [2:0] PAD_RIGHT = 3'd4;
	assign sd_dat1 = 1;
	assign sd_dat2 = 1;
	assign sd_dat3 = 1;
	reg [23:0] sd_romlen;
	wire sd_outen;
	wire [7:0] sd_outbyte;
	reg sd_loading;
	reg sd_op = 0;
	wire sd_done;
	reg sd_restart = 0;
	reg [11:0] sd_file;
	wire [415:0] sd_list_name;
	wire [7:0] sd_list_namelen;
	wire [11:0] sd_list_file;
	wire sd_list_en;
	assign dout = sd_outbyte;
	assign dout_valid = sd_loading & sd_outen;
	sd_file_list_reader #(
		.CLK_DIV(3'd1),
		.SIMULATE(0)
	) sd_reader_i(
		.rstn(resetn & ~sd_restart),
		.clk(clk),
		.sdclk(sd_clk),
		.sdcmd(sd_cmd),
		.sddat0(sd_dat0),
		.card_stat(),
		.card_type(),
		.filesystem_type(),
		.op(sd_op),
		.read_file(sd_file),
		.done(sd_done),
		.list_name(sd_list_name),
		.list_namelen(sd_list_namelen),
		.list_file_num(sd_list_file),
		.list_en(sd_list_en),
		.outen(sd_outen),
		.outbyte(sd_outbyte),
		.debug_read_done(),
		.debug_read_sector_no(),
		.debug_filesystem_state()
	);
	reg [3:0] state;
	localparam [3:0] SD_READ_DIR = 4'd1;
	localparam [3:0] SD_UI = 4'd3;
	localparam [3:0] SD_READ_ROM = 4'd4;
	localparam [3:0] SD_FAIL = 4'd14;
	localparam [3:0] SD_DONE = 4'd15;
	reg [7:0] X = 15;
	reg [7:0] Y = 40;
	wire [7:0] nx = (X == 255 ? 16 : X + 1);
	wire [7:0] ny = (X == 255 ? (Y == 200 ? 200 : Y + 1) : Y);
	wire [7:0] ch = (nx >> 3) - 2;
	wire [7:0] fn = (ny >> 3) - 5;
	always @(posedge clk)
		if (~resetn) begin
			sd_op <= 0;
			state <= SD_READ_DIR;
			sd_loading <= 0;
			overlay <= 0;
			file_start <= 1;
		end
		else begin
			sd_restart <= 0;
			overlay <= 0;
			case (state)
				SD_READ_DIR:
					if (sd_list_en) begin
						file_total <= sd_list_file;
						if ((sd_list_file >= file_start) && (sd_list_file < (file_start + 20))) begin
							X <= 15;
							Y <= 40 + ((sd_list_file - file_start) << 3);
							overlay <= 0;
						end
					end
					else if (sd_done)
						state <= SD_UI;
					else if (Y < 200) begin
						overlay <= 1;
						if ((fn + file_start) == sd_list_file) begin
							if (FONT[((((127 - sd_list_name[(51 - ch) * 8+:8]) * 8) + (7 - ny[2:0])) * 8) + nx[2:0]])
								color <= COLOR_TEXT;
							else
								color <= COLOR_BACK;
						end
						else
							color <= 13;
						X <= nx;
						cycle <= nx;
						Y <= ny;
						scanline <= ny;
					end
				SD_UI: begin
					if ((pad == PAD_UP) && (active != 0))
						active = active - 1;
					else if ((pad == PAD_DOWN) && (active != (total - 1)))
						active = active + 1;
					else if ((pad == PAD_RIGHT) && ((file_start + 20) <= file_total)) begin
						file_start <= file_start + 20;
						sd_restart <= 1;
						state <= SD_READ_DIR;
					end
					else if ((pad == PAD_LEFT) && (file_start > 1)) begin
						file_start <= file_start - 20;
						sd_restart <= 1;
						state <= SD_READ_DIR;
					end
					overlay <= 1;
					{cursor_now, cursor_dot} <= {cursor_now, cursor_dot} + 1;
					if ((cursor_now == (total - 1)) && (cursor_dot == 6'd63)) begin
						cursor_now <= 0;
						cursor_dot <= 0;
					end
					if ((cursor_now == active) && (total != 0))
						color <= (CURSOR[cursor_dot] ? COLOR_CURSOR : COLOR_BACK);
					else
						color <= COLOR_BACK;
					scanline <= (40 + (cursor_now << 3)) + cursor_dot[5:3];
					cycle <= cursor_dot[2:0];
					if (nes_btn[0] && (total != 0)) begin
						sd_op <= 1;
						sd_file <= active + file_start;
						sd_restart <= 1;
						overlay <= 0;
						sd_loading <= 1;
						state <= SD_READ_ROM;
					end
				end
				SD_READ_ROM:
					if (sd_outen)
						;
					else if (sd_done)
						sd_loading <= 0;
			endcase
		end
	reg [$clog2((FREQ / 5) + 1) - 1:0] debounce;
	wire deb = debounce == 0;
	always @(posedge clk) begin
		pad <= PAD_CENTER;
		if (~resetn) begin
			pad <= 0;
			debounce = 0;
		end
		else begin
			debounce = (debounce == 0 ? 0 : debounce - 1);
			if (nes_btn[7] && deb) begin
				pad <= PAD_RIGHT;
				debounce <= FREQ / 5;
			end
			if (nes_btn[6] && deb) begin
				pad <= PAD_LEFT;
				debounce <= FREQ / 5;
			end
			if (nes_btn[5] && deb) begin
				pad <= PAD_DOWN;
				debounce <= FREQ / 5;
			end
			if (nes_btn[4] && deb) begin
				pad <= PAD_UP;
				debounce <= FREQ / 5;
			end
		end
	end
	always @(*)
		case (debug_reg)
			8'h01: debug_out = file_total[7:0];
			8'h02: debug_out = file_total[11:8];
			8'h03: debug_out = file_start;
			8'h04: debug_out = active;
			8'h05: debug_out = total;
			8'h06: debug_out = state;
			default: debug_out = 0;
		endcase
endmodule
