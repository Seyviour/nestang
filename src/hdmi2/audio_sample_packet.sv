// Implementation of HDMI audio sample packet
// By Sameer Puri https://github.com/sameer

// Unless otherwise specified, all "See X" references will refer to the HDMI v1.4a specification.

// See Section 5.3.4
// 2-channel L-PCM or IEC 61937 audio in IEC 60958 frames with consumer grade IEC 60958-3.
module audio_sample_packet 
#(
    // A thorough explanation of the below parameters can be found in IEC 60958-3 5.2, 5.3.

    // 0 = Consumer, 1 = Professional
    parameter bit GRADE = 1'b0,

    // 0 = LPCM, 1 = IEC 61937 compressed
    parameter bit SAMPLE_WORD_TYPE = 1'b0,

    // 0 = asserted, 1 = not asserted
    parameter bit COPYRIGHT_NOT_ASSERTED = 1'b1,

    // 000 = no pre-emphasis, 001 = 50μs/15μs pre-emphasis
    parameter bit [2:0] PRE_EMPHASIS = 3'b000,

    // Only one valid value
    parameter bit [1:0] MODE = 2'b00,

    // Set to all 0s for general device.
    parameter bit [7:0] CATEGORY_CODE = 8'd0,

    // TODO: not really sure what this is...
    // 0 = "Do no take into account"
    parameter bit [3:0] SOURCE_NUMBER = 4'd0,

    // 0000 = 44.1 kHz
    parameter bit [3:0] SAMPLING_FREQUENCY = 4'b0000,

    // Normal accuracy: +/- 1000 * 10E-6 (00), High accuracy +/- 50 * 10E-6 (01)
    parameter bit [1:0] CLOCK_ACCURACY = 2'b00,

    // 3-bit representation of the number of bits to subtract (except 101 is actually subtract 0) with LSB first, followed by maxmium length of 20 bits (0) or 24 bits (1)
    parameter bit [3:0] WORD_LENGTH = 0,

    // Frequency prior to conversion in a consumer playback system. 0000 = not indicated.
    parameter bit [3:0] ORIGINAL_SAMPLING_FREQUENCY = 4'b0000,

    // 2-channel = 0, >= 3-channel = 1
    parameter bit LAYOUT = 1'b0

)
(
    input logic [7:0] frame_counter,
    // See IEC 60958-1 4.4 and Annex A. 0 indicates the signal is suitable for decoding to an analog audio signal.
    // input logic [1:0] valid_bit [3:0],
    input logic [2*4-1:0] valid_bit, 
    // See IEC 60958-3 Section 6. 0 indicates that no user data is being sent
    // input logic [1:0] user_data_bit [3:0],
    input logic [4*2-1:0] user_data_bit,
    // input logic [23:0] audio_sample_word [3:0] [1:0],
    input logic [24*4*2-1:0] audio_sample_word, 
    input logic [3:0] audio_sample_word_present,
    output logic [23:0] header,
    // output logic [55:0] sub [3:0]
    output logic [56*4-1:0] sub
);


logic [1:0] _valid_bit_ [3:0];
assign _valid_bit_[0] = valid_bit[1:0];
assign _valid_bit_[1] = valid_bit[2*2-1:2*1];
assign _valid_bit_[2] = valid_bit[3*2-1:2*2];
assign _valid_bit_[3] = valid_bit[4*2-1:3*2];  
// _wide_wire_to_array_(_valid_bit_, valid_bit, 2, 4, 1);

logic [1:0] _user_data_bit_ [3:0];
assign _user_data_bit_[0] = user_data_bit[1:0];
assign _user_data_bit_[1] = user_data_bit[2*2-1:2*1];
assign _user_data_bit_[2] = user_data_bit[3*2-1:2*2];
assign _user_data_bit_[3] = user_data_bit[4*2-1:3*2];  
// _wide_wire_to_array_(_user_data_bit_, user_data_bit, 2, 4,1);

logic [23:0] _audio_sample_word_ [3:0] [1:0];
assign _audio_sample_word_[0][0] = audio_sample_word[23:0]; 
assign _audio_sample_word_[0][1] = audio_sample_word[47:24]; 
assign _audio_sample_word_[1][0] = audio_sample_word[71:48]; 
assign _audio_sample_word_[1][1] = audio_sample_word[95:72]; 
assign _audio_sample_word_[2][0] = audio_sample_word[119:96]; 
assign _audio_sample_word_[2][1] = audio_sample_word[143:120]; 
assign _audio_sample_word_[3][0] = audio_sample_word[167:144]; 
assign _audio_sample_word_[3][1] = audio_sample_word[191:168]; 
// input logic [24*4*2-1:0] audio_sample_word;
// _wide_wire_to_array_(_audio_sample_word_, audio_sample_word, 23, 4, 2);

logic [55:0] _sub_ [3:0];
assign sub[55:0] = _sub_[0];
assign sub[111:56] = _sub_[1];
assign sub[167:112] = _sub_[2];
assign sub[223:168] = _sub_[3]; 


// Left/right channel for stereo audio
logic [3:0] CHANNEL_LEFT = 4'd1;
logic [3:0] CHANNEL_RIGHT = 4'd2;

localparam bit [7:0] CHANNEL_STATUS_LENGTH = 8'd192;
// See IEC 60958-1 5.1, Table 2
logic [192-1:0] channel_status_left;
assign channel_status_left = {152'd0, ORIGINAL_SAMPLING_FREQUENCY, WORD_LENGTH, 2'b00, CLOCK_ACCURACY, SAMPLING_FREQUENCY, CHANNEL_LEFT, SOURCE_NUMBER, CATEGORY_CODE, MODE, PRE_EMPHASIS, COPYRIGHT_NOT_ASSERTED, SAMPLE_WORD_TYPE, GRADE};
logic [CHANNEL_STATUS_LENGTH-1:0] channel_status_right;
assign channel_status_right = {152'd0, ORIGINAL_SAMPLING_FREQUENCY, WORD_LENGTH, 2'b00, CLOCK_ACCURACY, SAMPLING_FREQUENCY, CHANNEL_RIGHT, SOURCE_NUMBER, CATEGORY_CODE, MODE, PRE_EMPHASIS, COPYRIGHT_NOT_ASSERTED, SAMPLE_WORD_TYPE, GRADE};


// See HDMI 1.4a Table 5-12: Audio Sample Packet Header.
assign header[19:12] = {4'b0000, {3'b000, LAYOUT}};
assign header[7:0] = 8'd2;
logic [1:0] parity_bit [3:0];
logic [7:0] aligned_frame_counter [3:0];
genvar i;
generate
    for (i = 0; i < 4; i++)
    begin: sample_based_assign
        always_comb
        begin
            if (8'(frame_counter + i) >= CHANNEL_STATUS_LENGTH)
                aligned_frame_counter[i] = 8'(frame_counter + i - CHANNEL_STATUS_LENGTH);
            else
                aligned_frame_counter[i] = 8'(frame_counter + i);
        end
        assign header[23 - (3-i)] = aligned_frame_counter[i] == 8'd0 && audio_sample_word_present[i];
        assign header[11 - (3-i)] = audio_sample_word_present[i];
        assign parity_bit[i][0] = ^{channel_status_left[aligned_frame_counter[i]], _user_data_bit_[i][0], _valid_bit_[i][0], _audio_sample_word_[i][0]};
        assign parity_bit[i][1] = ^{channel_status_right[aligned_frame_counter[i]], _user_data_bit_[i][1], _valid_bit_[i][1], _audio_sample_word_[i][1]};
        // See HDMI 1.4a Table 5-13: Audio Sample Subpacket.
        always_comb
        begin
            if (audio_sample_word_present[i])
                _sub_[i] = {{parity_bit[i][1], channel_status_right[aligned_frame_counter[i]], _user_data_bit_[i][1], _valid_bit_[i][1], parity_bit[i][0], channel_status_left[aligned_frame_counter[i]], _user_data_bit_[i][0], _valid_bit_[i][0]}, _audio_sample_word_[i][1], _audio_sample_word_[i][0]};
            else
            `ifdef MODEL_TECH
                _sub_[i] = 56'd0;
            `else
                _sub_[i] = 56'dx;
            `endif
        end
    end
endgenerate

endmodule
