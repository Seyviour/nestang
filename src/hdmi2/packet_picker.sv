// Implementation of HDMI packet choice logic.
// By Sameer Puri https://github.com/sameer

module packet_picker
#(
    parameter int VIDEO_ID_CODE = 4,
    parameter real VIDEO_RATE = 0,
    parameter bit IT_CONTENT = 1'b0,
    parameter int AUDIO_BIT_WIDTH = 0,
    parameter int AUDIO_RATE = 48e3,
    parameter bit [8*8-1:0] VENDOR_NAME = 0,
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = 0,
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 0
)
(
    input logic clk_pixel,
    input logic clk_audio,
    input logic reset,
    input logic video_field_end,
    input logic packet_enable,
    input logic [4:0] packet_pixel_counter,
    input logic [AUDIO_BIT_WIDTH*2-1:0] audio_sample_word,
    output logic [23:0] header,
    // output logic [55:0] sub [3:0]
    output logic [56*4-1:0] sub
);
logic [AUDIO_BIT_WIDTH-1:0] _audio_sample_word_ [1:0]; 
assign _audio_sample_word_[0] = audio_sample_word[AUDIO_BIT_WIDTH-1:0];
assign _audio_sample_word_[1] = audio_sample_word[AUDIO_BIT_WIDTH*2-1:AUDIO_BIT_WIDTH]; 

logic [55:0] _sub_ [3:0];
assign sub[56*4-1:56*3] = _sub_[3];
assign sub[56*3-1:56*2] = _sub_[2];
assign sub[56*2-1:56*1] = _sub_[1];
assign sub[56*1-1:56*0] = _sub_[0]; 


// Connect the current packet type's data to the output.
logic [7:0] packet_type = 8'd0;
logic [23:0] headers [255:0];
logic [55:0] subs [255:0] [3:0];

logic [4*56-1:0] subs_132;  
logic [4*56-1:0] subs_131; 
logic [4*56-1:0] subs_130; 
logic [4*56-1:0] subs_2; 
logic [4*56-1:0] subs_1;

// assign subs[1] = subs_1;
assign subs[1][0] = subs_1[56*4-1:56*3];
assign subs[1][1] = subs_1[56*3-1:56*2];
assign subs[1][2] = subs_1[56*2-1:56*1];
assign subs[1][3] = subs_1[56*1-1:56*0];

// assign subs[2] = subs_2;
assign subs[2][0] = subs_2[56*4-1:56*3];
assign subs[2][1] = subs_2[56*3-1:56*2];
assign subs[2][2] = subs_2[56*2-1:56*1];
assign subs[2][3] = subs_2[56*1-1:56*0];

// assign subs[130] = subs_130;
assign subs[130][0] = subs_130[56*4-1:56*3];
assign subs[130][1] = subs_130[56*3-1:56*2];
assign subs[130][2] = subs_130[56*2-1:56*1];
assign subs[130][3] = subs_130[56*1-1:56*0];


// assign subs[131] = subs_131;
assign subs[131][0] = subs_131[56*4-1:56*3];
assign subs[131][1] = subs_131[56*3-1:56*2];
assign subs[131][2] = subs_131[56*2-1:56*1];
assign subs[131][3] = subs_131[56*1-1:56*0];

// assign subs[132] = subs_132; 
assign subs[132][0] = subs_132[56*4-1:56*3];
assign subs[132][1] = subs_132[56*3-1:56*2];
assign subs[132][2] = subs_132[56*2-1:56*1];
assign subs[132][3] = subs_132[56*1-1:56*0];

assign header = headers[packet_type];
assign _sub_[0] = subs[packet_type][0];
assign _sub_[1] = subs[packet_type][1];
assign _sub_[2] = subs[packet_type][2];
assign _sub_[3] = subs[packet_type][3];

// NULL packet
// "An HDMI Sink shall ignore bytes HB1 and HB2 of the Null Packet Header and all bytes of the Null Packet Body."
`ifdef MODEL_TECH
assign headers[0] = {8'd0, 8'd0, 8'd0}; assign subs[0] = '{56'd0, 56'd0, 56'd0, 56'd0};
`else
assign headers[0] = {8'dX, 8'dX, 8'd0};
assign subs[0][0] = 56'dX;
assign subs[0][1] = 56'dX;
assign subs[0][2] = 56'dX;
assign subs[0][3] = 56'dX;
`endif

// Audio Clock Regeneration Packet
logic clk_audio_counter_wrap;
audio_clock_regeneration_packet #(.VIDEO_RATE(VIDEO_RATE), .AUDIO_RATE(AUDIO_RATE)) audio_clock_regeneration_packet (.clk_pixel(clk_pixel), .clk_audio(clk_audio), .clk_audio_counter_wrap(clk_audio_counter_wrap), .header(headers[1]), .sub(subs_1));

// Audio Sample packet
localparam bit [3:0] SAMPLING_FREQUENCY = AUDIO_RATE == 32000 ? 4'b0011
    : AUDIO_RATE == 44100 ? 4'b0000
    : AUDIO_RATE == 88200 ? 4'b1000
    : AUDIO_RATE == 176400 ? 4'b1100
    : AUDIO_RATE == 48000 ? 4'b0010
    : AUDIO_RATE == 96000 ? 4'b1010
    : AUDIO_RATE == 192000 ? 4'b1110
    : 4'bXXXX;
localparam int AUDIO_BIT_WIDTH_COMPARATOR = AUDIO_BIT_WIDTH < 20 ? 20 : AUDIO_BIT_WIDTH == 20 ? 25 : AUDIO_BIT_WIDTH < 24 ? 24 : AUDIO_BIT_WIDTH == 24 ? 29 : -1;
localparam bit [2:0] WORD_LENGTH = 3'(AUDIO_BIT_WIDTH_COMPARATOR - AUDIO_BIT_WIDTH);
localparam bit WORD_LENGTH_LIMIT = AUDIO_BIT_WIDTH <= 20 ? 1'b0 : 1'b1;

logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word_transfer [1:0];
logic audio_sample_word_transfer_control = 1'd0;
always_ff @(posedge clk_audio)
begin
    // audio_sample_word_transfer <= audio_sample_word;
    audio_sample_word_transfer[0] <= audio_sample_word[AUDIO_BIT_WIDTH-1:0]; 
    audio_sample_word_transfer[1] <= audio_sample_word[AUDIO_BIT_WIDTH*2-1:AUDIO_BIT_WIDTH]; 
    audio_sample_word_transfer_control <= !audio_sample_word_transfer_control;
end

logic [1:0] audio_sample_word_transfer_control_synchronizer_chain = 2'd0;
always_ff @(posedge clk_pixel)
    audio_sample_word_transfer_control_synchronizer_chain <= {audio_sample_word_transfer_control, audio_sample_word_transfer_control_synchronizer_chain[1]};

logic sample_buffer_current = 1'b0;
logic [1:0] samples_remaining = 2'd0;
logic [23:0] audio_sample_word_buffer [1:0] [3:0] [1:0];
logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word_transfer_mux [1:0];
always_comb
begin
    if (audio_sample_word_transfer_control_synchronizer_chain[0] ^ audio_sample_word_transfer_control_synchronizer_chain[1]) begin
        audio_sample_word_transfer_mux[0] = audio_sample_word_transfer[0];
        audio_sample_word_transfer_mux[1] = audio_sample_word_transfer[1];
    end
    else begin
        
    end
        // audio_sample_word_transfer_mux = '{audio_sample_word_buffer[sample_buffer_current][samples_remaining][1][23:(24-AUDIO_BIT_WIDTH)], audio_sample_word_buffer[sample_buffer_current][samples_remaining][0][23:(24-AUDIO_BIT_WIDTH)]};
        // audio_sample_word_transfer_mux = {audio_sample_word_buffer[sample_buffer_current][samples_remaining][1][23:(24-AUDIO_BIT_WIDTH)], audio_sample_word_buffer[sample_buffer_current][samples_remaining][0][23:(24-AUDIO_BIT_WIDTH)]};
        {audio_sample_word_transfer_mux[1], audio_sample_word_transfer_mux[0]} = {audio_sample_word_buffer[sample_buffer_current][samples_remaining][1][23:(24-AUDIO_BIT_WIDTH)], audio_sample_word_buffer[sample_buffer_current][samples_remaining][0][23:(24-AUDIO_BIT_WIDTH)]};

end

logic sample_buffer_used = 1'b0;
logic sample_buffer_ready = 1'b0;

always_ff @(posedge clk_pixel)
begin
    if (sample_buffer_used)
        sample_buffer_ready <= 1'b0;

    if (audio_sample_word_transfer_control_synchronizer_chain[0] ^ audio_sample_word_transfer_control_synchronizer_chain[1])
    begin
        audio_sample_word_buffer[sample_buffer_current][samples_remaining][0] <=  24'(audio_sample_word_transfer_mux[0])<<(24-AUDIO_BIT_WIDTH);
        audio_sample_word_buffer[sample_buffer_current][samples_remaining][1] <=  24'(audio_sample_word_transfer_mux[1])<<(24-AUDIO_BIT_WIDTH);
        if (samples_remaining == 2'd3)
        begin
            samples_remaining <= 2'd0;
            sample_buffer_ready <= 1'b1;
            sample_buffer_current <= !sample_buffer_current;
        end
        else
            samples_remaining <= samples_remaining + 1'd1;
    end
end

logic [23:0] audio_sample_word_packet [3:0] [1:0];
logic [24*4*2-1:0] _audio_sample_word_packet_;
assign _audio_sample_word_packet_[23:0] = audio_sample_word_packet[0][0];
assign _audio_sample_word_packet_[47:24] = audio_sample_word_packet[0][1];
assign _audio_sample_word_packet_[71:48] = audio_sample_word_packet[1][0];
assign _audio_sample_word_packet_[95:72] = audio_sample_word_packet[1][1];
assign _audio_sample_word_packet_[119:96] = audio_sample_word_packet[2][0];
assign _audio_sample_word_packet_[143:120] = audio_sample_word_packet[2][1];
assign _audio_sample_word_packet_[167:144] = audio_sample_word_packet[3][0];
assign _audio_sample_word_packet_[191:168] = audio_sample_word_packet[3][1];

logic [3:0] audio_sample_word_present_packet;

logic [7:0] frame_counter = 8'd0;
int k;
always_ff @(posedge clk_pixel)
begin
    if (reset)
    begin
        frame_counter <= 8'd0;
    end
    else if (packet_pixel_counter == 5'd31 && packet_type == 8'h02) // Keep track of current IEC 60958 frame
    begin
        frame_counter = frame_counter + 8'd4;
        if (frame_counter >= 8'd192)
            frame_counter = frame_counter - 8'd192;
    end
end
// audio_sample_packet #(.SAMPLING_FREQUENCY(SAMPLING_FREQUENCY), .WORD_LENGTH({{WORD_LENGTH[0], WORD_LENGTH[1], WORD_LENGTH[2]}, WORD_LENGTH_LIMIT})) audio_sample_packet (.frame_counter(frame_counter), .valid_bit({2'b00, 2'b00, 2'b00, 2'b00}), .user_data_bit('{2'b00, 2'b00, 2'b00, 2'b00}), .audio_sample_word(audio_sample_word_packet), .audio_sample_word_present(audio_sample_word_present_packet), .header(headers[2]), .sub(subs[2]));
audio_sample_packet #(.SAMPLING_FREQUENCY(SAMPLING_FREQUENCY), .WORD_LENGTH({{WORD_LENGTH[0], WORD_LENGTH[1], WORD_LENGTH[2]}, WORD_LENGTH_LIMIT})) audio_sample_packet (.frame_counter(frame_counter), .valid_bit({8'b00_00_00_00}), .user_data_bit({8'b00_00_00_00}), .audio_sample_word(_audio_sample_word_packet_), .audio_sample_word_present(audio_sample_word_present_packet), .header(headers[2]), .sub(subs_2));



auxiliary_video_information_info_frame #(
    .VIDEO_ID_CODE(7'(VIDEO_ID_CODE)),
    .IT_CONTENT(IT_CONTENT)
) auxiliary_video_information_info_frame(.header(headers[130]), .sub(subs_130));

// source_product_description_info_frame #(.VENDOR_NAME(VENDOR_NAME), .PRODUCT_DESCRIPTION(PRODUCT_DESCRIPTION), .SOURCE_DEVICE_INFORMATION(SOURCE_DEVICE_INFORMATION)) source_product_description_info_frame(.header(headers[131]), .sub(subs[131]));
source_product_description_info_frame #(.VENDOR_NAME(VENDOR_NAME), .PRODUCT_DESCRIPTION(PRODUCT_DESCRIPTION), .SOURCE_DEVICE_INFORMATION(SOURCE_DEVICE_INFORMATION)) source_product_description_info_frame(.header(headers[131]), .sub(subs_131));

// audio_info_frame audio_info_frame(.header(headers[132]), .sub(subs[132]));
audio_info_frame audio_info_frame(.header(headers[132]), .sub(subs_132));


// "A Source shall always transmit... [an InfoFrame] at least once per two Video Fields"
logic audio_info_frame_sent = 1'b0;
logic auxiliary_video_information_info_frame_sent = 1'b0;
logic source_product_description_info_frame_sent = 1'b0;
logic last_clk_audio_counter_wrap = 1'b0;
always_ff @(posedge clk_pixel)
begin
    if (sample_buffer_used)
        sample_buffer_used <= 1'b0;

    if (reset || video_field_end)
    begin
        audio_info_frame_sent <= 1'b0;
        auxiliary_video_information_info_frame_sent <= 1'b0;
        source_product_description_info_frame_sent <= 1'b0;
        packet_type <= 8'dx;
    end
    else if (packet_enable)
    begin
        if (last_clk_audio_counter_wrap ^ clk_audio_counter_wrap)
        begin
            packet_type <= 8'd1;
            last_clk_audio_counter_wrap <= clk_audio_counter_wrap;
        end
        else if (sample_buffer_ready)
        begin
            packet_type <= 8'd2;
            //shuriken
            // audio_sample_word_packet <= audio_sample_word_buffer[!sample_buffer_current];
            audio_sample_word_packet[0][0] <= audio_sample_word_buffer[!sample_buffer_current][0][0];
            audio_sample_word_packet[0][1] <= audio_sample_word_buffer[!sample_buffer_current][0][1];
            audio_sample_word_packet[1][0] <= audio_sample_word_buffer[!sample_buffer_current][1][0];
            audio_sample_word_packet[1][1] <= audio_sample_word_buffer[!sample_buffer_current][1][1];
            audio_sample_word_packet[2][0] <= audio_sample_word_buffer[!sample_buffer_current][2][0];
            audio_sample_word_packet[2][1] <= audio_sample_word_buffer[!sample_buffer_current][2][1];
            audio_sample_word_packet[3][0] <= audio_sample_word_buffer[!sample_buffer_current][3][0];
            audio_sample_word_packet[3][1] <= audio_sample_word_buffer[!sample_buffer_current][3][1];

            audio_sample_word_present_packet <= 4'b1111;
            sample_buffer_used <= 1'b1;
        end
        else if (!audio_info_frame_sent)
        begin
            packet_type <= 8'h84;
            audio_info_frame_sent <= 1'b1;
        end
        else if (!auxiliary_video_information_info_frame_sent)
        begin
            packet_type <= 8'h82;
            auxiliary_video_information_info_frame_sent <= 1'b1;
        end
        else if (!source_product_description_info_frame_sent)
        begin
            packet_type <= 8'h83;
            source_product_description_info_frame_sent <= 1'b1;
        end
        else
            packet_type <= 8'd0;
    end
end

endmodule
