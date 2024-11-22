module binning (
  input wire clk_in,
  input wire rst_in,
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire pixel_bit, // pixel data for one line
  
  output logic valid_out,
  output logic [8:0] hcount_out,
  output logic [7:0] vcount_out,
  output logic binned_output
);

  localparam H_RES = 1280;

  logic [H_RES-1:0][2:0] line_buffer;
  logic [4:0] count_ones;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      line_buffer <= 0;
      valid_out <= 0'b0;
      binned_output <= 0'b0;
    end else begin
      if (vcount_in[1:0] == 2'b11) begin
        if (hcount_in[1:0] == 2'b0 && hcount_in != 0) begin // we've hit the 4x4
          if (count_ones >= 8) binned_output <= 1;
          else binned_output <= 0;

          valid_out <= 1;
          hcount_out <= hcount_in[10:2] - 1;
          vcount_out <= vcount_in[9:2];

          count_ones <= line_buffer[hcount_in] + pixel_bit;

        end else begin // we are at a 0 mod 4 vcount but not yet at 0 mod 4 hcount in
          count_ones <= count_ones + line_buffer[hcount_in] + pixel_bit;
          line_buffer[hcount_in] <= 0; // resetting line_buffer
          valid_out <= 0;

        end
      end else begin // non 0 mod 4 vcount
        line_buffer[hcount_in] <= line_buffer[hcount_in] + pixel_bit;
      end
    end
  end

endmodule