module sd_file_list_reader (
	rstn,
	clk,
	sdclk,
	sdcmd,
	sddat0,
	op,
	read_file,
	done,
	card_stat,
	card_type,
	filesystem_type,
	file_found,
	list_name,
	list_namelen,
	list_file_num,
	list_en,
	outen,
	outbyte,
	debug_read_done,
	debug_read_sector_no,
	debug_filesystem_state
);
	parameter [2:0] CLK_DIV = 3'd2;
	parameter SIMULATE = 0;
	input wire rstn;
	input wire clk;
	output wire sdclk;
	inout sdcmd;
	input wire sddat0;
	input op;
	input [11:0] read_file;
	// output wire [2:0] done;
	output wire done; 
	output wire [3:0] card_stat;
	output wire [1:0] card_type;
	output wire [1:0] filesystem_type;
	output reg file_found;
	output wire [415:0] list_name;
	output wire [7:0] list_namelen;
	output reg [11:0] list_file_num;
	output wire list_en;
	output reg outen;
	output reg [7:0] outbyte;
	output wire debug_read_done;
	output wire [31:0] debug_read_sector_no;
	output wire debug_filesystem_state;
	initial file_found = 1'b0;
	initial {outen, outbyte} = 0;
	reg read_start = 1'b0;
	reg [31:0] read_sector_no = 0;
	wire read_done;
	assign debug_read_done = read_done;
	assign debug_read_sector_no = read_sector_no;
	wire rvalid;
	wire [8:0] raddr;
	wire [7:0] rdata;
	reg [31:0] rootdir_sector = 0;
	reg [31:0] rootdir_sector_t;
	reg [15:0] rootdir_sectorcount = 0;
	reg [15:0] rootdir_sectorcount_t;
	reg [31:0] curr_cluster = 0;
	reg [31:0] curr_cluster_t;
	wire [6:0] curr_cluster_fat_offset;
	wire [24:0] curr_cluster_fat_no;
	assign {curr_cluster_fat_no, curr_cluster_fat_offset} = curr_cluster;
	wire [7:0] curr_cluster_fat_offset_fat16;
	wire [23:0] curr_cluster_fat_no_fat16;
	assign {curr_cluster_fat_no_fat16, curr_cluster_fat_offset_fat16} = curr_cluster;
	reg [31:0] target_cluster = 0;
	reg [15:0] target_cluster_fat16 = 16'h0000;
	reg [7:0] cluster_sector_offset = 8'h00;
	reg [7:0] cluster_sector_offset_t;
	reg [31:0] file_cluster = 0;
	reg [31:0] file_size = 0;
	reg [7:0] cluster_size = 0;
	reg [7:0] cluster_size_t;
	reg [31:0] first_fat_sector_no = 0;
	reg [31:0] first_fat_sector_no_t;
	reg [31:0] first_data_sector_no = 0;
	reg [31:0] first_data_sector_no_t;
	reg search_fat = 1'b0;
	localparam [2:0] RESET = 3'd0;
	localparam [2:0] SEARCH_MBR = 3'd1;
	localparam [2:0] SEARCH_DBR = 3'd2;
	localparam [2:0] LS_ROOT_FAT16 = 3'd3;
	localparam [2:0] LS_ROOT_FAT32 = 3'd4;
	localparam [2:0] READ_A_FILE = 3'd5;
	localparam [2:0] DONE = 3'd6;
	// (* fsm_encoding = "user" *)
	reg [2:0] filesystem_state; 
	initial filesystem_state = RESET;
	assign debug_filesystem_state = filesystem_state;
	assign done = filesystem_state == DONE;
	localparam [1:0] UNASSIGNED = 2'd0;
	localparam [1:0] UNKNOWN = 2'd1;
	localparam [1:0] FAT16 = 2'd2;
	localparam [1:0] FAT32 = 2'd3;
	reg [1:0] filesystem = UNASSIGNED;
	reg [1:0] filesystem_parsed;
	assign filesystem_type = filesystem;
	integer ii;
	integer i;
	reg [7:0] sector_content [0:511];
	initial for (ii = 0; ii < 512; ii = ii + 1)
		sector_content[ii] = 0;
	
	always @(posedge clk)
		if (rvalid)
			sector_content[raddr] <= rdata;
	wire is_boot_sector = {sector_content['h1fe], sector_content['h1ff]} == 16'h55aa;
	wire is_dbr = (sector_content[0] == 8'heb) || (sector_content[0] == 8'he9);
	wire [31:0] dbr_sector_no = {sector_content['h1c9], sector_content['h1c8], sector_content['h1c7], sector_content['h1c6]};
	wire [15:0] bytes_per_sector = {sector_content['hc], sector_content['hb]};
	wire [7:0] sector_per_cluster = sector_content['hd];
	wire [15:0] resv_sectors = {sector_content['hf], sector_content['he]};
	wire [7:0] number_of_fat = sector_content['h10];
	wire [15:0] rootdir_itemcount = {sector_content['h12], sector_content['h11]};
	reg [31:0] sectors_per_fat = 0;
	reg [31:0] root_cluster = 0;
	always @(*) begin
		sectors_per_fat = {16'h0000, sector_content['h17], sector_content['h16]};
		root_cluster = 0;
		if (sectors_per_fat > 0)
			filesystem_parsed = FAT16;
		else if (sector_content['h56] == 8'h32) begin
			filesystem_parsed = FAT32;
			sectors_per_fat = {sector_content['h27], sector_content['h26], sector_content['h25], sector_content['h24]};
			root_cluster = {sector_content['h2f], sector_content['h2e], sector_content['h2d], sector_content['h2c]};
		end
		else
			filesystem_parsed = UNKNOWN;
	end
    
    logic [39:0] cluster_size_t_curr_cluster_t; 
    logic [39:0] sectors_per_fat_number_of_fat;
    logic [8:0] cluster_size_t_x_2; 
    
    
//    assign cluster_size_t_curr_cluster_t = curr_cluster_t << xlog2 (cluster_size_t); 
//    assign sectors_per_fat_number_of_fat = sectors_per_fat << 1'b1; 
//    assign cluster_size_t_x_2 = (cluster_size_t << 1'b1); 
    
    function automatic [2:0] xlog2(input logic [7:0] in_val);
        case (in_val)
            8'b0000_0001: xlog2 = 3'd0;
            8'b0000_0010: xlog2 = 3'd1;
            8'b0000_0100: xlog2 = 3'd2;
            8'b0000_1000: xlog2 = 3'd3;
            8'b0001_0000: xlog2 = 3'd4;
            8'b0010_0000: xlog2 = 3'd5;
            8'b0100_0000: xlog2 = 3'd6;
            8'b1000_0000: xlog2 = 3'd7;
            default:      xlog2 = 3'd0; 
        endcase
    endfunction


	always @(posedge clk or negedge rstn)
		if (!rstn) begin
			filesystem_state <= RESET;
			read_start <= 1'b0;
			read_sector_no <= 0;
			filesystem <= UNASSIGNED;
			search_fat <= 1'b0;
			cluster_size <= 8'h00;
			first_fat_sector_no <= 0;
			first_data_sector_no <= 0;
			curr_cluster <= 0;
			cluster_sector_offset <= 8'h00;
			rootdir_sector <= 0;
			rootdir_sectorcount <= 16'h0000;
		end
		else begin
			cluster_size_t = cluster_size;
			first_fat_sector_no_t = first_fat_sector_no;
			first_data_sector_no_t = first_data_sector_no;
			curr_cluster_t = curr_cluster;
			cluster_sector_offset_t = cluster_sector_offset;
			rootdir_sector_t = rootdir_sector;
			rootdir_sectorcount_t = rootdir_sectorcount;
			read_start <= 1'b0;
			if (read_done)
				case (filesystem_state)
					SEARCH_MBR:
						if (is_boot_sector) begin
							filesystem_state <= SEARCH_DBR;
							if (~is_dbr)
								read_sector_no <= dbr_sector_no;
						end
						else
							read_sector_no <= read_sector_no + 1;
					SEARCH_DBR:
						if (is_boot_sector && is_dbr) begin
							if (bytes_per_sector != 16'd512)
								filesystem_state <= DONE;
							else begin
								filesystem <= filesystem_parsed;
								if (filesystem_parsed == FAT16) begin
									cluster_size_t = sector_per_cluster;
									first_fat_sector_no_t = read_sector_no + resv_sectors;
									rootdir_sectorcount_t = rootdir_itemcount >> 4'd4; // / (16'd512 / 16'd32);
									rootdir_sector_t = first_fat_sector_no_t + (sectors_per_fat << 1'b1);
									first_data_sector_no_t = (rootdir_sector_t + rootdir_sectorcount_t) - (cluster_size_t << 1'b1);
									cluster_sector_offset_t = 8'h00;
									read_sector_no <= rootdir_sector_t + cluster_sector_offset_t;
									filesystem_state <= LS_ROOT_FAT16;
								end
								else if (filesystem_parsed == FAT32) begin
									cluster_size_t = sector_per_cluster;
									first_fat_sector_no_t = read_sector_no + resv_sectors;
									first_data_sector_no_t = (first_fat_sector_no_t + (sectors_per_fat << 1'b1)) - (cluster_size_t << 1'b1);
									curr_cluster_t = root_cluster;
									cluster_sector_offset_t = 8'h00;
									read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
									filesystem_state <= LS_ROOT_FAT32;
								end
								else
									filesystem_state <= DONE;
							end
						end
					LS_ROOT_FAT16:
						if (file_found) begin
							curr_cluster_t = file_cluster;
							cluster_sector_offset_t = 8'h00;
							read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
							filesystem_state <= READ_A_FILE;
						end
						else if (cluster_sector_offset_t < rootdir_sectorcount_t) begin
							cluster_sector_offset_t = cluster_sector_offset_t + 8'd1;
							read_sector_no <= rootdir_sector_t + cluster_sector_offset_t;
						end
						else
							filesystem_state <= DONE;
					LS_ROOT_FAT32:
						if (~search_fat) begin
							if (file_found) begin
							// if (0) begin
								curr_cluster_t = file_cluster;
								cluster_sector_offset_t = 8'h00;
								read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
								filesystem_state <= READ_A_FILE;
							end
							else if (cluster_sector_offset_t < (cluster_size_t - 1)) begin
							// else if (0) begin
								cluster_sector_offset_t = cluster_sector_offset_t + 8'd1;
								read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
							end
							else begin
								search_fat <= 1'b1;
								cluster_sector_offset_t = 8'h00;
								read_sector_no <= first_fat_sector_no_t + curr_cluster_fat_no;
							end
						end
						else begin
							search_fat <= 1'b0;
							cluster_sector_offset_t = 8'h00;
							// filesystem_state <= DONE;
							if ((((target_cluster == 32'h0fffffff) || (target_cluster == 32'h0ffffff8)) || (target_cluster == 32'hffffffff)) || (target_cluster < 2))
							// if (1)
								filesystem_state <= DONE;
							else begin
								curr_cluster_t = target_cluster;
								read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
							end
						end
					READ_A_FILE:
						if (~search_fat) begin
							if (cluster_sector_offset_t < (cluster_size_t - 1)) begin
								cluster_sector_offset_t = cluster_sector_offset_t + 8'd1;
								read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
							end
							else begin
								search_fat <= 1'b1;
								cluster_sector_offset_t = 8'h00;
								read_sector_no <= first_fat_sector_no_t + (filesystem == FAT16 ? curr_cluster_fat_no_fat16 : curr_cluster_fat_no);
							end
						end
						else begin
							search_fat <= 1'b0;
							cluster_sector_offset_t = 8'h00;
							if (filesystem == FAT16) begin
								if ((target_cluster_fat16 >= 16'hfff0) || (target_cluster_fat16 < 16'h0002))
									filesystem_state <= DONE;
								else begin
									curr_cluster_t = {16'h0000, target_cluster_fat16};
									read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
								end
							end
							else if ((((target_cluster == 'hfffffff) || (target_cluster == 'hffffff8)) || (target_cluster == 'hffffffff)) || (target_cluster < 2))
								filesystem_state <= DONE;
							else begin
								curr_cluster_t = target_cluster;
								read_sector_no <= (first_data_sector_no_t + (curr_cluster_t << xlog2 (cluster_size_t))) + cluster_sector_offset_t;
							end
						end
				endcase
			else
				case (filesystem_state)
					RESET: filesystem_state <= SEARCH_MBR;
					SEARCH_MBR: read_start <= 1'b1;
					SEARCH_DBR: read_start <= 1'b1;
					LS_ROOT_FAT16: read_start <= 1'b1;
					LS_ROOT_FAT32: read_start <= 1'b1;
					READ_A_FILE: read_start <= 1'b1;
				endcase
			cluster_size <= cluster_size_t;
			first_fat_sector_no <= first_fat_sector_no_t;
			first_data_sector_no <= first_data_sector_no_t;
			curr_cluster <= curr_cluster_t;
			cluster_sector_offset <= cluster_sector_offset_t;
			rootdir_sector <= rootdir_sector_t;
			rootdir_sectorcount <= rootdir_sectorcount_t;
		end
	// generate
	// 	if (SIMULATE) begin : genblk1
	// 		always @(posedge clk)
	// 			if (read_done)
	// 				;
	// 			else if (filesystem_state == DONE)
	// 				$finish;
	// 	end
	// endgenerate
	always @(posedge clk or negedge rstn)
		if (~rstn) begin
			target_cluster <= 0;
			target_cluster_fat16 <= 16'h0000;
		end
		else if (search_fat && rvalid) begin
			if (filesystem == FAT16) begin
				if (raddr[8:1] == curr_cluster_fat_offset_fat16)
					// target_cluster_fat16[8 * raddr[0]+:8] <= rdata;
				case (raddr[0])
					1'b0: target_cluster_fat16[7:0] <= rdata;
					1'b1: target_cluster_fat16[15:8] <= rdata;
				endcase
				// target_cluster_fat16[(raddr[0]<<2'd3)+:8] <= rdata;

			end
			else if (filesystem == FAT32) begin
				if (raddr[8:2] == curr_cluster_fat_offset)
					// target_cluster[8 * raddr[1:0]+:8] <= rdata;
				case (raddr[1:0])
					2'b00: target_cluster[7:0] <= rdata;
					2'b01: target_cluster[15:8] <= rdata;
					2'b10: target_cluster[23:16] <= rdata;
					2'b11: target_cluster[31:24] <= rdata; 
				endcase
				// target_cluster[(raddr[1:0] << 2'd3)+:8] <= rdata;
			end
		end
	sd_reader #(
		.CLK_DIV(CLK_DIV),
		.SIMULATE(SIMULATE)
	) u_sd_reader(
		.rstn(rstn),
		.clk(clk),
		.sdclk(sdclk),
		.sdcmd(sdcmd),
		.sddat0(sddat0),
		.card_type(card_type),
		.card_stat(card_stat),
		.rstart(read_start),
		.rsector(read_sector_no),
		.rbusy(),
		.rdone(read_done),
		.outen(rvalid),
		.outaddr(raddr),
		.outbyte(rdata)
	);
	reg fready = 1'b0;
	assign list_en = fready;
	reg [7:0] fnamelen = 0;
	reg [15:0] fcluster = 0;
	reg [31:0] fsize = 0;
	reg [415:0] fname;
	assign list_name = fname;
	assign list_namelen = fnamelen;
	reg [7:0] file_name [0:51];
	reg isshort = 1'b0;
	reg islongok = 1'b0;
	reg islong = 1'b0;
	reg longvalid = 1'b0;
	reg isshort_t;
	reg islongok_t;
	reg islong_t;
	reg longvalid_t;
	reg [5:0] longno = 6'h00;
	reg [5:0] longno_t;
	reg [7:0] lastchar = 8'h00;
	reg [7:0] fdtnamelen = 8'h00;
	reg [7:0] fdtnamelen_t;
	reg [7:0] sdtnamelen = 8'h00;
	reg [7:0] sdtnamelen_t;
	reg [7:0] file_namelen = 8'h00;
	reg [15:0] file_1st_cluster = 16'h0000;
	reg [15:0] file_1st_cluster_t;
	reg [31:0] file_1st_size = 0;
	reg [31:0] file_1st_size_t;
	initial for (i = 0; i < 52; i = i + 1)
		begin
			file_name[i] = 8'h00;
			fname[(51 - i) * 8+:8] = 8'h00;
		end
	always @(posedge clk or negedge rstn)
		if (~rstn) begin
			fready <= 1'b0;
			fnamelen <= 8'h00;
			file_namelen <= 8'h00;
			fcluster <= 16'h0000;
			fsize <= 0;
			for (i = 0; i < 52; i = i + 1)
				begin
					file_name[i] <= 8'h00;
					fname[((51 - i) << 2'd3)+:8] <= 8'h00;
				end
			{isshort, islongok, islong, longvalid} <= 4'b0000;
			longno <= 6'h00;
			lastchar <= 8'h00;
			fdtnamelen <= 8'h00;
			sdtnamelen <= 8'h00;
			file_1st_cluster <= 16'h0000;
			file_1st_size <= 0;
		end
		else begin
			{isshort_t, islongok_t, islong_t, longvalid_t} = {isshort, islongok, islong, longvalid};
			longno_t = longno;
			fdtnamelen_t = fdtnamelen;
			sdtnamelen_t = sdtnamelen;
			file_1st_cluster_t = file_1st_cluster;
			file_1st_size_t = file_1st_size;
			fready <= 1'b0;
			fnamelen <= 8'h00;
			fcluster <= 16'h0000;
			fsize <= 0;
			if (filesystem_state == SEARCH_MBR)
				list_file_num <= 0;
			if ((rvalid && ((filesystem_state == LS_ROOT_FAT16) || (filesystem_state == LS_ROOT_FAT32))) && ~search_fat) begin
				case (raddr[4:0])
					5'h1a: file_1st_cluster_t[0+:8] = rdata;
					5'h1b: file_1st_cluster_t[8+:8] = rdata;
					5'h1c: file_1st_size_t[0+:8] = rdata;
					5'h1d: file_1st_size_t[8+:8] = rdata;
					5'h1e: file_1st_size_t[16+:8] = rdata;
					5'h1f: file_1st_size_t[24+:8] = rdata;
				endcase
				if (raddr[4:0] == 5'h00) begin
					{islongok_t, isshort_t} = 2'b00;
					fdtnamelen_t = 8'h00;
					sdtnamelen_t = 8'h00;
					if (((rdata != 8'he5) && (rdata != 8'h2e)) && (rdata != 8'h00)) begin
						if (islong_t && (longno_t == 6'h01))
							islongok_t = 1'b1;
						else
							isshort_t = 1'b1;
					end
					if ((rdata[7] == 1'b0) && ~islongok_t) begin
						if (rdata[6]) begin
							{islong_t, longvalid_t} = 2'b11;
							longno_t = rdata[5:0];
						end
						else if (islong_t) begin
							if ((longno_t > 6'h01) && ((rdata[5:0] + 6'h01) == longno_t)) begin
								islong_t = 1'b1;
								longno_t = rdata[5:0];
							end
							else
								islong_t = 1'b0;
						end
						else
							islong_t = 1'b0;
					end
					else
						islong_t = 1'b0;
				end
				else if (raddr[4:0] == 5'h0b) begin
					if (rdata != 8'h0f)
						islong_t = 1'b0;
					if ((rdata != 8'h20) && (rdata != 8'h21))
						{isshort_t, islongok_t} = 2'b00;
				end
				else if (raddr[4:0] == 5'h1f) begin
					if ((islongok_t && longvalid_t) || isshort_t) begin
						fready <= 1'b1;
						fnamelen <= file_namelen;
						list_file_num <= list_file_num + 1;
						for (i = 0; i < 52; i = i + 1)
							fname[((51 - i) << 2'd3 )+:8] <= (i < file_namelen ? file_name[i] : 8'h00);
						fcluster <= file_1st_cluster_t;
						fsize <= file_1st_size_t;
					end
				end
				if (islong_t) begin
					if ((((raddr[4:0] > 5'h00) && (raddr[4:0] < 5'h0b)) || ((raddr[4:0] >= 5'h0e) && (raddr[4:0] < 5'h1a))) || (raddr[4:0] >= 5'h1c)) begin
						if ((raddr[4:0] < 5'h0b ? raddr[0] : ~raddr[0])) begin
							lastchar <= rdata;
							fdtnamelen_t = fdtnamelen_t + 8'd1;
						end
						else if ({rdata, lastchar} == 16'h0000)
                            file_namelen <= (fdtnamelen_t - 8'd1) + (((longno_t<<3'd3) + (longno_t<<3'd2) + longno_t) - 8'd13);
//							file_namelen <= (fdtnamelen_t - 8'd1) + ((longno_t - 8'd1) * 8'd13);
						else if ({rdata, lastchar} != 16'hffff) begin
							if (rdata == 8'h00)
								file_name[(fdtnamelen_t - 8'd1) + (((longno_t<<3'd3) + (longno_t<<3'd2) + longno_t) - 8'd13)] <= lastchar;
							else
								longvalid_t = 1'b0;
						end
					end
				end
				if (isshort_t) begin
					if (raddr[4:0] < 5'h08) begin
						if (rdata != 8'h20) begin
							file_name[sdtnamelen_t] <= rdata;
							sdtnamelen_t = sdtnamelen_t + 8'd1;
						end
					end
					else if (raddr[4:0] < 5'h0b) begin
						if (raddr[4:0] == 5'h08) begin
							file_name[sdtnamelen_t] <= 8'h2e;
							sdtnamelen_t = sdtnamelen_t + 8'd1;
						end
						if (rdata != 8'h20) begin
							file_name[sdtnamelen_t] <= rdata;
							sdtnamelen_t = sdtnamelen_t + 8'd1;
						end
					end
					else if (raddr[4:0] == 5'h0b)
						file_namelen <= sdtnamelen_t;
				end
			end
			{isshort, islongok, islong, longvalid} <= {isshort_t, islongok_t, islong_t, longvalid_t};
			longno <= longno_t;
			fdtnamelen <= fdtnamelen_t;
			sdtnamelen <= sdtnamelen_t;
			file_1st_cluster <= file_1st_cluster_t;
			file_1st_size <= file_1st_size_t;
		end
	always @(posedge clk or negedge rstn)
		if (~rstn) begin
			file_found <= 1'b0;
			file_cluster <= 0;
			file_size <= 0;
		end
		else if ((fready && op) && (list_file_num == read_file)) begin
			file_found <= 1'b1;
			file_cluster <= fcluster;
			file_size <= fsize;
		end
	reg [31:0] fptr = 0;
	always @(posedge clk or negedge rstn)
		if (~rstn) begin
			fptr <= 0;
			{outen, outbyte} <= 0;
		end
		else if (((rvalid && (filesystem_state == READ_A_FILE)) && ~search_fat) && (fptr < file_size)) begin
			fptr <= fptr + 1;
			{outen, outbyte} <= {1'b1, rdata};
		end
		else
			{outen, outbyte} <= 0;
endmodule
