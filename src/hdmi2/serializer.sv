`define GW_IDE

module serializer
#(
    parameter int NUM_CHANNELS = 3,
    parameter real VIDEO_RATE
)
(
    input logic clk_pixel,
    input logic clk_pixel_x5,
    input logic reset,
    // input logic [9:0] tmds_internal [NUM_CHANNELS-1:0],
    input logic [10*NUM_CHANNELS-1:0] tmds_internal,
    output logic [2:0] tmds,
    output logic tmds_clock
);

genvar i; 
wire [9:0] _tmds_internal_ [NUM_CHANNELS-1:0]; 
generate
    for (i=0; i<NUM_CHANNELS; i=i+1) begin 
       assign _tmds_internal_[i] = tmds_internal[(i+1)*10-1:i*10]; 
    end
endgenerate


OSER10 gwSer0( 
    .Q( tmds[ 0 ] ),
    .D0(_tmds_internal_[ 0 ][ 0 ] ),
    .D1(_tmds_internal_[ 0 ][ 1 ] ),
    .D2(_tmds_internal_[ 0 ][ 2 ] ),
    .D3(_tmds_internal_[ 0 ][ 3 ] ),
    .D4(_tmds_internal_[ 0 ][ 4 ] ),
    .D5(_tmds_internal_[ 0 ][ 5 ] ),
    .D6(_tmds_internal_[ 0 ][ 6 ] ),
    .D7(_tmds_internal_[ 0 ][ 7 ] ),
    .D8(_tmds_internal_[ 0 ][ 8 ] ),
    .D9(_tmds_internal_[ 0 ][ 9 ] ),
    .PCLK( clk_pixel ),
    .FCLK( clk_pixel_x5 ),
    .RESET( reset ) );

OSER10 gwSer1( 
    .Q( tmds[ 1 ] ),
    .D0(_tmds_internal_[ 1 ][ 0 ] ),
    .D1(_tmds_internal_[ 1 ][ 1 ] ),
    .D2(_tmds_internal_[ 1 ][ 2 ] ),
    .D3(_tmds_internal_[ 1 ][ 3 ] ),
    .D4(_tmds_internal_[ 1 ][ 4 ] ),
    .D5(_tmds_internal_[ 1 ][ 5 ] ),
    .D6(_tmds_internal_[ 1 ][ 6 ] ),
    .D7(_tmds_internal_[ 1 ][ 7 ] ),
    .D8(_tmds_internal_[ 1 ][ 8 ] ),
    .D9(_tmds_internal_[ 1 ][ 9 ] ),
    .PCLK( clk_pixel ),
    .FCLK( clk_pixel_x5 ),
    .RESET( reset ) );

OSER10 gwSer2( 
    .Q( tmds[ 2 ] ),
    .D0(_tmds_internal_[ 2 ][ 0 ] ),
    .D1(_tmds_internal_[ 2 ][ 1 ] ),
    .D2(_tmds_internal_[ 2 ][ 2 ] ),
    .D3(_tmds_internal_[ 2 ][ 3 ] ),
    .D4(_tmds_internal_[ 2 ][ 4 ] ),
    .D5(_tmds_internal_[ 2 ][ 5 ] ),
    .D6(_tmds_internal_[ 2 ][ 6 ] ),
    .D7(_tmds_internal_[ 2 ][ 7 ] ),
    .D8(_tmds_internal_[ 2 ][ 8 ] ),
    .D9(_tmds_internal_[ 2 ][ 9 ] ),
    .PCLK( clk_pixel ),
    .FCLK( clk_pixel_x5 ),
    .RESET( reset ) );
    
assign tmds_clock = clk_pixel;
endmodule