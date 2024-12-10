`default_nettype none

module center_of_mass #(
    parameter int HRES = 320,
    parameter int VRES = 180
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
  localparam int HWIDTH = $clog2(HRES);
  localparam int VWIDTH = $clog2(VRES);

  logic [HWIDTH+VWIDTH+HWIDTH-1:0] x_sum;
  logic [HWIDTH+VWIDTH+VWIDTH-1:0] y_sum;
  logic [HWIDTH+VWIDTH-1:0] count;

  logic [HWIDTH+VWIDTH+HWIDTH-1:0] x_div_out;
  logic [HWIDTH+VWIDTH+VWIDTH-1:0] y_div_out;
  logic x_valid_out, y_valid_out;
  logic x_valid, y_valid;

  divider #(
      .WIDTH(HWIDTH + VWIDTH + HWIDTH)
  ) x_divider (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(x_sum),
      .divisor_in(count),
      .data_valid_in(tabulate_in),
      .quotient_out(x_div_out),
      .remainder_out(),
      .data_valid_out(x_valid_out),
      .busy_out()
  );

  divider #(
      .WIDTH(HWIDTH + VWIDTH + VWIDTH)
  ) y_divider (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(y_sum),
      .divisor_in(count),
      .data_valid_in(tabulate_in),
      .quotient_out(y_div_out),
      .remainder_out(),
      .data_valid_out(y_valid_out),
      .busy_out()
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      x_out <= 0;
      y_out <= 0;
      valid_out <= 0;
      x_sum <= 0;
      y_sum <= 0;
      count <= 0;
      x_valid <= 0;
      y_valid <= 0;
    end else begin
      if (valid_in) begin
        x_sum <= x_sum + x_in;
        y_sum <= y_sum + y_in;
        count <= count + 1;
      end
      if (tabulate_in) begin
        x_sum   <= 0;
        y_sum   <= 0;
        count   <= 0;
        x_valid <= 0;
        y_valid <= 0;
      end
      if (x_valid_out) begin
        x_out   <= x_div_out;
        x_valid <= 1;
      end
      if (y_valid_out) begin
        y_out   <= y_div_out;
        y_valid <= 1;
      end
      if (x_valid && y_valid) begin
        valid_out <= 1;
        x_valid   <= 0;
        y_valid   <= 0;
      end else begin
        valid_out <= 0;
      end
    end
  end
endmodule

`default_nettype wire
