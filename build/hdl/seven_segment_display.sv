`timescale 1ns / 1ps `default_nettype none

module seven_segment_display #(
    parameter COUNT_TO = 100000
) (
    input  wire         clk_in,
    input  wire         rst_in,
    input  wire  [31:0] bin_in,
    input  wire  [ 7:0] enable_in,
    output logic [ 6:0] cat_out,
    output logic [ 7:0] an_out
);

  logic [ 7:0] segment_state;
  logic [31:0] segment_counter;
  logic [ 6:0] led_out;
  logic [ 3:0] routed_vals;
  logic [ 6:0] bto7s_led_out;

  assign cat_out = ~led_out;
  assign an_out  = ~segment_state;

  always_comb begin
    case (segment_state)
      8'b0000_0001: led_out = enable_in[0] ? bto7s_led_out : 7'b0000000;
      8'b0000_0010: led_out = enable_in[1] ? bto7s_led_out : 7'b0000000;
      8'b0000_0100: led_out = enable_in[2] ? bto7s_led_out : 7'b0000000;
      8'b0000_1000: led_out = enable_in[3] ? bto7s_led_out : 7'b0000000;
      8'b0001_0000: led_out = enable_in[4] ? bto7s_led_out : 7'b0000000;
      8'b0010_0000: led_out = enable_in[5] ? bto7s_led_out : 7'b0000000;
      8'b0100_0000: led_out = enable_in[6] ? bto7s_led_out : 7'b0000000;
      8'b1000_0000: led_out = enable_in[7] ? bto7s_led_out : 7'b0000000;
      default:      led_out = 7'b0000000;
    endcase
  end

  always_comb begin
    case (segment_state)
      8'b0000_0001: routed_vals = bin_in[3:0];
      8'b0000_0010: routed_vals = bin_in[7:4];
      8'b0000_0100: routed_vals = bin_in[11:8];
      8'b0000_1000: routed_vals = bin_in[15:12];
      8'b0001_0000: routed_vals = bin_in[19:16];
      8'b0010_0000: routed_vals = bin_in[23:20];
      8'b0100_0000: routed_vals = bin_in[27:24];
      8'b1000_0000: routed_vals = bin_in[31:28];
      default:      routed_vals = 4'b0;
    endcase
  end


  bto7s mbto7s (
      .x_in (routed_vals),
      .s_out(bto7s_led_out)
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      segment_state   <= 8'b0000_0001;
      segment_counter <= 32'b0;
    end else begin
      if (segment_counter == COUNT_TO) begin
        segment_counter <= 32'd0;
        segment_state   <= {segment_state[6:0], segment_state[7]};
      end else begin
        segment_counter <= segment_counter + 1;
      end
    end
  end
endmodule  //seven_segment_controller


`default_nettype wire

