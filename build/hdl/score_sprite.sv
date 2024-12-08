//takes in a number from scorer and displays things for video mux
// hasn't been tested but might wokr
module score_sprite(
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire [2:0] score, // actual score
  output logic score_pixel_valid_out, // tells the other rgb values that they should use this pixel
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out);

  localparam int SEG_L = 64;
  localparam int SEG_W = 8;
  localparam int X_IN_0 = 128;
  localparam int Y_IN_0 = 128;
  localparam int SEG_WIDTHS[7] = '{SEG_L, SEG_W, SEG_W, SEG_L, SEG_W, SEG_W, SEG_L};
  localparam int SEG_HEIGHTS[7] = '{SEG_W, SEG_L, SEG_L, SEG_W, SEG_L, SEG_L, SEG_W};
  localparam int X_INS[7] = '{X_IN_0, X_IN_0+SEG_L, X_IN_0+SEG_L, X_IN_0, X_IN_0-SEG_W, X_IN_0-SEG_W, X_IN_0};
  localparam int Y_INS[7] = '{Y_IN_0, Y_IN_0+SEG_W, Y_IN_0+2*SEG_W+SEG_L, Y_IN_0+2*SEG_W+2*SEG_L, Y_IN_0+2*SEG_W+SEG_L, Y_IN_0+SEG_W, Y_IN_0+SEG_W+SEG_L};
  logic [7:0] num;
  logic [6:0] block_valids;
  logic [6:0] in_blocks;
  logic [23:0] score_color;
  always_comb begin
    block_valids[0] = num[0] || num[2] || num[3] || num[5] || num[6] || num[7];
    block_valids[1] = num[0] || num[1] || num[2] || num[3] || num[4] || num[7];
    block_valids[2] = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7];
    block_valids[3] = num[0] || num[2] || num[3] || num[5] || num[6];
    block_valids[4] = num[0] || num[2] || num[6];
    block_valids[5] = num[0] || num[4] || num[5] || num[6];
    block_valids[6] = num[2] || num[3] || num[4] || num[5] || num[6];
    case (score)
      3'b000: score_color = 24'h00_FF_00; // Green
      3'b001: score_color = 24'h44_FF_00;
      3'b010: score_color = 24'h88_FF_00;
      3'b011: score_color = 24'hCC_FF_00;
      3'b100: score_color = 24'hFF_CC_00;
      3'b101: score_color = 24'hFF_88_00;
      3'b110: score_color = 24'hFF_44_00;
      3'b111: score_color = 24'hFF_00_00; // Most red
      default: score_color = 24'h00_00_00; // Default to black
    endcase
    
    red_out = score_color[23:16];
    green_out = score_color[15:8];
    blue_out = score_color[7:0];
    score_pixel_valid_out = (in_blocks > 0) ? 1 : 0;
  end

  
  generate
    genvar j;
    for (j=0; j<8; j=j+1)begin
      assign num[j] = (score == j);
    end
  endgenerate

  generate
    genvar i;
    for (i = 0; i < 7; i = i + 1) begin
      block_sprite #(
          .WIDTH(SEG_WIDTHS[i]),
          .HEIGHT(SEG_HEIGHTS[i])
      ) seven_segment (
        .hcount_in(hcount_in),
        .vcount_in(vcount_in),
        .x_in(X_INS[i]),
        .y_in(Y_INS[i]),
        .color_in(score_color),
        .valid_in(block_valids[i]),
        .in_block(in_blocks[i])
      );
    end
  endgenerate
endmodule