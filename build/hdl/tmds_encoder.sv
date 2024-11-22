`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  //your code here.

  logic [4:0] tally;
  logic [3:0] num_ones;
  logic [3:0] num_zeros;
  always_comb begin
    num_ones = 3'b0;
    num_zeros = 3'b0;
    for (int i = 0; i < 8; i = i + 1) begin // get number of 1s in q_m[7:0]
        num_ones = num_ones + q_m[i];
      end
    num_zeros = 8-num_ones;
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      tmds_out <= 0;
      tally <= 0;
    end else begin // reset is lifted

    if (ve_in == 0) begin
      case (control_in)
        2'b00: tmds_out <= 10'b1101010100;
        2'b01: tmds_out <= 10'b0010101011;
        2'b10: tmds_out <= 10'b0101010100;
        2'b11: tmds_out <= 10'b1010101011;
      endcase 
      tally <= 0;
    end else begin // ve_in == 1
        
      if (tally == 0 || (num_ones == num_zeros)) begin // first check if tally is 0 or if one and zeros are the same
        tmds_out[9] <= ~q_m[8];
        tmds_out[8] <= q_m[8];
        tmds_out[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
        if (q_m[8] == 0) begin
          tally <= tally + (num_zeros - num_ones);
        end else begin //q_m[8] == 1
          tally <= tally + (num_ones - num_zeros);
        end
      end else begin // further cases
      
        if ((tally[4] == 0 && (num_ones > num_zeros)) || (tally[4] == 1 && (num_zeros > num_ones))) begin
          tmds_out[9] <= 1'b1;
          tmds_out[8] <= q_m[8];
          tmds_out[7:0] <= ~q_m[7:0];
          tally <= tally + 2*{4'b0, q_m[8]} + num_zeros - num_ones;

        end else begin //other case
          tmds_out[9] <= 1'b0;
          tmds_out[8] <= q_m[8];
          tmds_out[7:0] <= q_m[7:0];
          tally <= tally - 2*{4'b0, ~q_m[8]} + num_ones - num_zeros;
        end
      end 
      end
    end 
  end

endmodule //end tmds_encoder