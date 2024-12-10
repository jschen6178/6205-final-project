`timescale 1ns / 1ps `default_nettype none

module divider #(
    parameter WIDTH = 8
) (
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              data_valid_in,   // Start signal
    input  wire  [WIDTH-1:0] dividend_in,     // Dividend input
    input  wire  [WIDTH-1:0] divisor_in,      // Divisor input
    output logic [WIDTH-1:0] quotient_out,    // Quotient output
    output logic [WIDTH-1:0] remainder_out,   // Remainder output
    output logic             data_valid_out,
    output logic             busy_out
);

  logic [WIDTH-1:0] temp_dividend;
  logic [WIDTH-1:0] temp_divisor;
  logic [WIDTH-1:0] temp_quotient;
  logic [WIDTH:0] temp_remainder;
  logic [$clog2(WIDTH+1)-1:0] count;  // Counter for the bit-wise iteration

  typedef enum logic [1:0] {
    IDLE,
    DIVIDE,
    FINISH
  } state_t;

  state_t state;

  assign busy_out = state != IDLE;

  // Sequential logic for the state machine
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      data_valid_out <= 1'b0;
      quotient_out <= 0;
      remainder_out <= 0;
    end else begin
      case (state)
        IDLE: begin
          data_valid_out <= 1'b0;
          if (data_valid_in) begin
            temp_dividend <= dividend_in;
            temp_divisor <= divisor_in;
            temp_quotient <= 0;
            temp_remainder <= 0;
            count <= WIDTH - 1;
            state <= DIVIDE;
          end
        end
        DIVIDE: begin
          temp_dividend <= temp_dividend << 1;
          if (((temp_remainder << 1) | temp_dividend[WIDTH-1]) >= temp_divisor) begin
            temp_remainder <= ((temp_remainder << 1) | temp_dividend[WIDTH-1]) - temp_divisor;
            temp_quotient  <= (temp_quotient << 1) | 1'b1;
          end else begin
            temp_remainder <= (temp_remainder << 1) | temp_dividend[WIDTH-1];
            temp_quotient  <= temp_quotient << 1;
          end
          if (count == 0) begin
            state <= FINISH;
          end else begin
            count <= count - 1;
          end
        end
        FINISH: begin
          quotient_out <= temp_quotient;
          remainder_out <= temp_remainder;
          data_valid_out <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
