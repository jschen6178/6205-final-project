`timescale 1ns / 1ps `default_nettype none

//module takes in a 8 bit pixel and given two threshold values it:
//produces a 1 bit output indicating if the pixel is between (inclusive)
//those two threshold values
module threshold (
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] y_in,
    cr_in,
    cb_in,
    input wire [7:0] y_cutoff,
    cr_cutoff,
    cb_cutoff,
    output logic mask_out
);
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      mask_out <= 0;
    end else begin
      mask_out <= (y_in > y_cutoff) && (cr_in < cr_cutoff) && (cb_in < cb_cutoff);
    end
  end
endmodule


`default_nettype wire
