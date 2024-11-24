`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module video_mux (
    input wire [1:0] bg_in,  //regular video
    input wire bin_in,
    input wire [23:0] camera_pixel_in,  //16 bits from camera 5:6:5
    input wire thresholded_pixel_in,  //
    output logic [23:0] pixel_out
);

  /*
  00: normal camera out
  01: channel image (in grayscale)
  10: (thresholded channel image b/w)
  11: y channel with magenta mask

  upper bits:
  00: nothing:
  01: crosshair
  10: sprite on top
  11: nothing (orange test color)
  */

  logic [23:0] l_1;
  always_comb begin
    case (bg_in)
      2'b00:   l_1 = camera_pixel_in;
      2'b01:   l_1 = (bin_in != 0) ? 24'h00FF00 : camera_pixel_in;
      2'b10:   l_1 = (thresholded_pixel_in != 0) ? 24'hFFFFFF : 24'h000000;
      2'b11:   l_1 = (thresholded_pixel_in != 0) ? 24'hFF77AA : camera_pixel_in;
      default: l_1 = camera_pixel_in;
    endcase
  end

  assign pixel_out = l_1;
endmodule

`default_nettype wire
