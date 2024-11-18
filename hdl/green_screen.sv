`timescale 1ns / 1ps
`default_nettype none

// module takes in rgb and outputs a 1 bit mask for green screen purposes
// green is 0
module green_screen(
  input wire [7:0] r_in, g_in, b_in,
  input wire [10:0] hcount,
  input wire [9:0] vcount,
  output logic bit_mask
);
logic signed [8:0] signed_r_in, signed_g_in, signed_b_in;

localparam LOWER_THRESHOLD = 64;
localparam UPPER_THRESHOLD = 248;

assign signed_r_in = $signed({0, r_in});
assign signed_g_in = $signed({0, g_in});
assign signed_b_in = $signed({0, b_in});

assign bit_mask = ((signed_g_in - signed_r_in - signed_b_in) > LOWER_THRESHOLD) ? 0 : 1;


endmodule