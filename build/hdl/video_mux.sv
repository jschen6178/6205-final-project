`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module video_mux (
    input wire [1:0] bg_in, //decides what we want to see
    input wire bin_in,
    input wire [23:0] camera_pixel_in,  //16 bits from camera 5:6:5
    input wire thresholded_pixel_in,  //
    input wire benchmark_skeleton_bit,
    output logic [23:0] pixel_out
);

  /*
  00: nothing, just normal HD video
  01: greenscreen max
  */

  logic [23:0] l_1;
  always_comb begin
    case (bg_in)
      2'b00:   l_1 = camera_pixel_in;
      2'b01:   l_1 = (benchmark_skeleton_bit != 0) ? 24'h0000FF : (bin_in != 0) ? 24'hFF0000 : camera_pixel_in;
      2'b10:   l_1 = (benchmark_skeleton_bit != 0) ? 24'h0000FF : (bin_in != 0) ? 24'hFF0000 : camera_pixel_in;
      2'b11:   l_1 = (thresholded_pixel_in != 0) ? 24'hFF77AA : camera_pixel_in;
      default: l_1 = camera_pixel_in;
    endcase
  end

  assign pixel_out = l_1;
endmodule

`default_nettype wire
