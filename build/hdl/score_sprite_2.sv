//takes in a number from scorer and displays things for video mux
// this one has been tested and works
module score_sprite_2(
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire [2:0] score, // actual score
  output logic score_pixel_valid_out, // tells the other rgb values that they should use this pixel
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out);

  localparam int SEG_L = 64;
  localparam int SEG_W = 8;
  localparam int X_IN_0 = 8;
  localparam int Y_IN_0 = 8;

  logic [10:0] seg_width_a, seg_width_b, seg_width_c, seg_width_d, seg_width_e, seg_width_f, seg_width_g;
  logic [10:0] seg_height_a, seg_height_b, seg_height_c, seg_height_d, seg_height_e, seg_height_f, seg_height_g;
  logic [10:0] x_in_a, x_in_b, x_in_c, x_in_d, x_in_e, x_in_f, x_in_g;
  logic [9:0] y_in_a, y_in_b, y_in_c, y_in_d, y_in_e, y_in_f, y_in_g;

  always_comb begin
  seg_width_a = SEG_L;
  seg_width_b = SEG_W;
  seg_width_c = SEG_W;
  seg_width_d = SEG_L;
  seg_width_e = SEG_W;
  seg_width_f = SEG_W;
  seg_width_g = SEG_L;

  seg_height_a = SEG_W;
  seg_height_b = SEG_L;
  seg_height_c = SEG_L;
  seg_height_d = SEG_W;
  seg_height_e = SEG_L;
  seg_height_f = SEG_L;
  seg_height_g = SEG_W;

  x_in_a = X_IN_0;
  x_in_b = X_IN_0 + SEG_L;
  x_in_c = X_IN_0 + SEG_L;
  x_in_d = X_IN_0;
  x_in_e = X_IN_0 - SEG_W;
  x_in_f = X_IN_0 - SEG_W;
  x_in_g = X_IN_0;

  y_in_a = Y_IN_0;
  y_in_b = Y_IN_0 + SEG_W;
  y_in_c = Y_IN_0 + 2 * SEG_W + SEG_L;
  y_in_d = Y_IN_0 + 2 * SEG_W + 2 * SEG_L;
  y_in_e = Y_IN_0 + 2 * SEG_W + SEG_L;
  y_in_f = Y_IN_0 + SEG_W;
  y_in_g = Y_IN_0 + SEG_W + SEG_L;
  end

  logic [7:0] num;
  logic block_valid_a, block_valid_b, block_valid_c, block_valid_d, block_valid_e, block_valid_f, block_valid_g;
  logic in_block_a, in_block_b, in_block_c, in_block_d, in_block_e, in_block_f, in_block_g;
  logic [23:0] score_color;

  generate
    genvar j;
    for (j=0; j<8; j=j+1)begin
      assign num[j] = (score == j);
    end
  endgenerate

  always_comb begin
    block_valid_a = num[0] || num[2] || num[3] || num[5] || num[6] || num[7];
    block_valid_b = num[0] || num[1] || num[2] || num[3] || num[4] || num[7];
    block_valid_c = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7];
    block_valid_d = num[0] || num[2] || num[3] || num[5] || num[6];
    block_valid_e = num[0] || num[2] || num[6];
    block_valid_f = num[0] || num[4] || num[5] || num[6];
    block_valid_g = num[2] || num[3] || num[4] || num[5] || num[6];
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
    score_pixel_valid_out = in_block_a || in_block_b || in_block_c || in_block_d || in_block_e || in_block_f || in_block_g;
  end

  block_sprite seven_segment_a (
    .width(seg_width_a),
    .height(seg_height_a),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_a),
    .y_in(y_in_a),
    .color_in(score_color),
    .valid_in(block_valid_a),
    .in_block(in_block_a)
  );

  block_sprite seven_segment_b (
    .width(seg_width_b),
    .height(seg_height_b),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_b),
    .y_in(y_in_b),
    .color_in(score_color),
    .valid_in(block_valid_b),
    .in_block(in_block_b)
  );

  block_sprite seven_segment_c (
    .width(seg_width_c),
    .height(seg_height_c),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_c),
    .y_in(y_in_c),
    .color_in(score_color),
    .valid_in(block_valid_c),
    .in_block(in_block_c)
  );

  block_sprite seven_segment_d (
    .width(seg_width_d),
    .height(seg_height_d),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_d),
    .y_in(y_in_d),
    .color_in(score_color),
    .valid_in(block_valid_d),
    .in_block(in_block_d)
  );

  block_sprite seven_segment_e (
    .width(seg_width_e),
    .height(seg_height_e),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_e),
    .y_in(y_in_e),
    .color_in(score_color),
    .valid_in(block_valid_e),
    .in_block(in_block_e)
  );

  block_sprite seven_segment_f (
    .width(seg_width_f),
    .height(seg_height_f),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_f),
    .y_in(y_in_f),
    .color_in(score_color),
    .valid_in(block_valid_f),
    .in_block(in_block_f)
  );

  block_sprite seven_segment_g (
    .width(seg_width_g),
    .height(seg_height_g),
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(x_in_g),
    .y_in(y_in_g),
    .color_in(score_color),
    .valid_in(block_valid_g),
    .in_block(in_block_g)
  );
endmodule