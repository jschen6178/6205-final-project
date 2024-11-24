`default_nettype none

// what is happening is we are using 4 line buffers, and when we are writing to the 4th line buffer we 
// will start counting
module binning_2 #(
    parameter int HRES = 1280,
    parameter int VRES = 720,
    parameter int DATA_WIDTH = 1,
    parameter int KERNEL_SIZE = 4
) (
    input wire clk_in,  //system clock
    input wire rst_in,  //system reset

    input wire [HWIDTH-1:0] hcount_in,  //current hcount being read
    input wire [VWIDTH-1:0] vcount_in,  //current vcount being read
    input wire [DATA_WIDTH-1:0] pixel_data_in,  //incoming pixel
    input wire data_valid_in,  //incoming  valid data signal

    output logic pixel_data_out,  //output pixel of data
    output logic [HWIDTH-3:0] hcount_out,  //current hcount being read
    output logic [VWIDTH-3:0] vcount_out,  //current vcount being read
    output logic data_valid_out  //valid data out signal
);
  localparam int HWIDTH = $clog2(HRES);
  localparam int VWIDTH = $clog2(VRES);
  localparam int LOG_MAX_COUNT = $clog2(KERNEL_SIZE * KERNEL_SIZE);

  logic [KERNEL_SIZE-1:0] weebs;
  logic [KERNEL_SIZE-1:0][DATA_WIDTH-1:0] pixel_outs;
  logic [LOG_MAX_COUNT] mask_count;

  logic data_valid_in_pipe;
  logic [HWIDTH-1:0] hcount_in_pipe;
  logic [VWIDTH-1:0] vcount_in_pipe;

  logic [VWIDTH-1:0] vcount_shifted;

  always_comb begin
    if (vcount_in_pipe == 0) begin
      vcount_shifted = VRES - 2;
    end else if (vcount_in_pipe == 1) begin
      vcount_shifted = VRES - 1;
    end else begin
      vcount_shifted = vcount_in_pipe - 2;
    end
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      weebs <= 1'b1 << KERNEL_SIZE;
      data_valid_out <= 1'b0;
      data_valid_in_pipe <= 1'b0;
    end else begin
      data_valid_in_pipe <= data_valid_in;
      if (data_valid_in_pipe) begin
        hcount_in_pipe <= hcount_in;
        vcount_in_pipe <= vcount_in;
        hcount_out <= hcount_in_pipe[HWIDTH-1:2];
        vcount_out <= vcount_shifted[VWIDTH-1:2];
        
        case (weebs)
          4'b1000: begin
            if (hcount_in[1:0] == 2'b10) begin
              data_valid_out <= 1'b1;
              pixel_data_out <= (mask_count + pixel_outs[0] + pixel_outs[1] + pixel_outs[2] + pixel_data_in) > 8 ? 1 : 0;
              mask_count <= 0;
            end else begin
              data_valid_out <= 0;
              mask_count <= mask_count + pixel_outs[0] + pixel_outs[1] + pixel_outs[2] + pixel_data_in;
            end
          end
          
          default: begin
          end
        endcase
        if (vcount_in != vcount_in_pipe) begin
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
    for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
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
