module block_sprite(
  input wire [10:0] height,
  input wire [10:0] width,
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire [10:0] x_in,
  input wire [9:0]  y_in,
  input wire [23:0] color_in,
  input wire valid_in,
  output logic in_block
  );

  assign in_block = valid_in && ((hcount_in >= x_in && hcount_in < (x_in + width)) &&
                                (vcount_in >= y_in && vcount_in < (y_in + height)));
endmodule