`timescale 1ns / 1ps
`default_nettype none

module zoomed_address_generator (
  input wire          clk_in,
  input wire          rst_in,
  input wire          incr_in,
  input wire [11:0]   center_x_in,
  input wire [10:0]   center_y_in,
  output logic [26:0] addr_out,
  output logic        tlast_out
);

  // use to keep track of what part of the output you're currently trying to draw.
  logic [10:0] hcount_display;
  logic [9:0]  vcount_display;

  // your logic here!

endmodule

`default_nettype wire
