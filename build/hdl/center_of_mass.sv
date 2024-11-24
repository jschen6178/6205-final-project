`default_nettype none

module center_of_mass (
    input wire clk_in,
    input wire rst_in,
    input wire [10:0] x_in,
    input wire [9:0] y_in,
    input wire valid_in,
    input wire tabulate_in,
    output logic [10:0] x_out,
    output logic [9:0] y_out,
    output logic valid_out
);
  // your code here

  logic [31:0] x_sum;
  logic [31:0] y_sum;
  logic [31:0] x_count;
  logic [31:0] y_count;
  logic need_output, x_done, y_done;

  logic x_valid_out, y_valid_out, x_error_out, y_error_out, x_busy_out, y_busy_out;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      x_count <= 0;
      y_count <= 0;
      x_sum <= 0;
      y_sum <= 0;
      x_done <= 0;
      y_done <= 0;
      valid_out <= 0;
    end else begin
      if (valid_in) begin
        x_sum   <= x_sum + x_in;
        y_sum   <= y_sum + y_in;
        x_count <= x_count + 1;
        y_count <= y_count + 1;

      end else if (tabulate_in) begin  // final calculation
        need_output <= 1;  // set to 0 once the dividers are done
        x_sum <= 0;
        y_sum <= 0;
        x_count <= 0;
        y_count <= 0;

      end

      if (x_valid_out) x_done <= 1;
      if (y_valid_out) y_done <= 1;

      if (need_output) begin
        if (x_done & y_done) begin
          need_output <= 0;
          x_done <= 0;
          y_done <= 0;
          valid_out <= 1;
        end
      end

      if (valid_out) valid_out <= 0;
    end
  end

  divider #(
      .WIDTH(32)
  ) x_divider (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(x_sum),
      .divisor_in(x_count),
      .data_valid_in(tabulate_in),
      .quotient_out(x_out),
      .remainder_out(),
      .data_valid_out(x_valid_out),
      .error_out(x_error_out),
      .busy_out(x_busy_out)
  );

  divider #(
      .WIDTH(32)
  ) y_divider (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(y_sum),
      .divisor_in(y_count),
      .data_valid_in(tabulate_in),
      .quotient_out(y_out),
      .remainder_out(),
      .data_valid_out(y_valid_out),
      .error_out(y_error_out),
      .busy_out(y_busy_out)
  );
endmodule

`default_nettype wire
