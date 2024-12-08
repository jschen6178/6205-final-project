`default_nettype none

module center_of_mass #(
    parameter int HORIZONTAL_COUNT = 320,
    parameter int VERTICAL_COUNT   = 180
) (
    input wire clk_in,
    input wire rst_in,
    input wire [HWIDTH-1:0] x_in,
    input wire [VWIDTH-1:0] y_in,
    input wire valid_in,
    input wire tabulate_in,
    output logic [HWIDTH-1:0] x_out,
    output logic [VWIDTH-1:0] y_out,
    output logic valid_out
);
  localparam int HWIDTH = $clog2(HORIZONTAL_COUNT);
  localparam int VWIDTH = $clog2(VERTICAL_COUNT);
  // your code here

  logic [HWIDTH+VWIDTH+HWIDTH-1:0] x_sum;
  logic [HWIDTH+VWIDTH+VWIDTH-1:0] y_sum;
  logic [HWIDTH+VWIDTH-1:0] x_count;
  logic [HWIDTH+VWIDTH-1:0] y_count;
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
      .WIDTH(HWIDTH + VWIDTH + HWIDTH)
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
      .WIDTH(HWIDTH + VWIDTH + VWIDTH)
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
