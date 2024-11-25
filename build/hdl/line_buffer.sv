`default_nettype none

module line_buffer #(
    parameter int HRES = 1280,
    parameter int VRES = 720,
    parameter int DATA_WIDTH = 16,
    parameter int KERNEL_SIZE = 3
) (
    input wire clk_in,  //system clock
    input wire rst_in,  //system reset

    input wire [$clog2(HRES)-1:0] hcount_in,  //current hcount being read
    input wire [$clog2(VRES)-1:0] vcount_in,  //current vcount being read
    input wire [DATA_WIDTH-1:0] pixel_data_in,  //incoming pixel
    input wire data_valid_in,  //incoming  valid data signal

    output logic [KERNEL_SIZE-1:0][DATA_WIDTH-1:0] line_buffer_out,  //output pixels of data
    output logic [HWIDTH-1:0] hcount_out,  //current hcount being read, binned down 4x
    output logic [VWIDTH-1:0] vcount_out,  //current vcount being read, binned down 4x
    output logic data_valid_out  //valid data out signal
);
  localparam int HWIDTH = $clog2(HRES);
  localparam int VWIDTH = $clog2(VRES);

  logic [KERNEL_SIZE:0] weebs;
  logic [KERNEL_SIZE:0][DATA_WIDTH-1:0] pixel_outs;

  logic data_valid_in_pipe[0:1];
  logic [HWIDTH-1:0] hcount_in_pipe[0:1];
  logic [VWIDTH-1:0] vcount_in_pipe[0:1];

  logic [VWIDTH-1:0] vcount_shifted;

  always_comb begin
    if (vcount_in_pipe[1] == 0) begin
      vcount_shifted = VRES - 2;
    end else if (vcount_in_pipe[1] == 1) begin
      vcount_shifted = VRES - 1;
    end else begin
      vcount_shifted = vcount_in_pipe[1] - 2;
    end
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      weebs <= 1'b1 << KERNEL_SIZE;
      data_valid_out <= 1'b0;
      data_valid_in_pipe[0] <= 1'b0;
      data_valid_in_pipe[1] <= 1'b0;
    end else begin
      data_valid_in_pipe[0] <= data_valid_in;
      data_valid_in_pipe[1] <= data_valid_in_pipe[0];
      if (data_valid_in) begin
        hcount_in_pipe[0] <= hcount_in;
        hcount_in_pipe[1] <= hcount_in_pipe[0];
        vcount_in_pipe[0] <= vcount_in;
        vcount_in_pipe[1] <= vcount_in_pipe[0];
      end
      if (data_valid_in_pipe[1]) begin
        hcount_out <= hcount_in_pipe[1];
        vcount_out <= vcount_shifted;
        data_valid_out <= 1'b1;
        case (weebs)
          4'b1000: begin
            line_buffer_out[0] <= pixel_outs[0];
            line_buffer_out[1] <= pixel_outs[1];
            line_buffer_out[2] <= pixel_outs[2];
          end
          4'b0001: begin
            line_buffer_out[0] <= pixel_outs[1];
            line_buffer_out[1] <= pixel_outs[2];
            line_buffer_out[2] <= pixel_outs[3];
          end
          4'b0010: begin
            line_buffer_out[0] <= pixel_outs[2];
            line_buffer_out[1] <= pixel_outs[3];
            line_buffer_out[2] <= pixel_outs[0];
          end
          4'b0100: begin
            line_buffer_out[0] <= pixel_outs[3];
            line_buffer_out[1] <= pixel_outs[0];
            line_buffer_out[2] <= pixel_outs[1];
          end
          default: begin
            // For debugging
            line_buffer_out[0] <= 16'h000F;
            line_buffer_out[1] <= 16'h00F0;
            line_buffer_out[2] <= 16'h0F00;
          end
        endcase
        if (vcount_in_pipe[0] != vcount_in_pipe[1]) begin
          weebs <= {weebs[2:0], weebs[3]};
        end
      end else begin
        data_valid_out <= 1'b0;
      end
    end
  end

  // to help you get started, here's a bram instantiation.
  // you'll want to create one BRAM for each row in the kernel, plus one more to
  // buffer incoming data from the wire:
  generate
    genvar i;
    for (i = 0; i < KERNEL_SIZE + 1; i = i + 1) begin
      xilinx_true_dual_port_read_first_1_clock_ram #(
          .RAM_WIDTH(DATA_WIDTH),
          .RAM_DEPTH(HRES),
          .RAM_PERFORMANCE("HIGH_PERFORMANCE")
      ) line_buffer_ram (
          .clka  (clk_in),         // Clock
          //writing port:
          .addra (hcount_in),      // Port A address bus,
          .dina  (pixel_data_in),  // Port A RAM input data
          .wea   (weebs[i]),       // Port A write enable
          //reading port:
          .addrb (hcount_in),      // Port B address bus,
          .doutb (pixel_outs[i]),  // Port B RAM output data,
          .douta (),               // Port A RAM output data, width determined from RAM_WIDTH
          .dinb  (0),              // Port B RAM input data, width determined from RAM_WIDTH
          .web   (1'b0),           // Port B write enable
          .ena   (1'b1),           // Port A RAM Enable
          .enb   (1'b1),           // Port B RAM Enable,
          .rsta  (1'b0),           // Port A output reset
          .rstb  (1'b0),           // Port B output reset
          .regcea(1'b1),           // Port A output register enable
          .regceb(1'b1)            // Port B output register enable
      );
    end
  endgenerate
endmodule

`default_nettype wire
