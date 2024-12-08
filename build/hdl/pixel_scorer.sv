module pixel_scorer #(
    parameter int HRES = 320,
    parameter int VRES = 180
) (
    input wire clk_in,
    input wire rst_in,
    // Any reference pose skeleton inputted MUST be inputted in order,
    // starting from 0, 0 and going to HRES-1, VRES-1
    input wire [HWIDTH-1:0] pixel_hcount_in,  // Hcount of input pixel, if valid
    input wire [VWIDTH-1:0] pixel_vcount_in,
    input wire pixel_in,  // Input skeleton to use as reference pose
    input wire pixel_valid_in,  // If this is set to valid, the module will not output a valid score
    input wire [HWIDTH-1:0] hcount_in, // Hcount of pixel query, only use if pixel_valid_in is false
    input wire [VWIDTH-1:0] vcount_in,
    output logic [HWIDTH-1:0] hcount_out,
    output logic [VWIDTH-1:0] vcount_out,
    output logic [DWIDTH-1:0] distance_out,
    output logic data_valid_out
);
  localparam int HWIDTH = $clog2(HRES);
  localparam int VWIDTH = $clog2(VRES);
  localparam int ADDR_WIDTH = $clog2(HRES * VRES);
  localparam int INF = HRES + VRES;  // Larger than the largest possible distance
  localparam int DWIDTH = $clog2(INF + 1);

  logic [ADDR_WIDTH-1:0] read_addr;
  logic [DWIDTH-1:0] read_data;
  logic [ADDR_WIDTH-1:0] write_addr;
  logic [DWIDTH-1:0] write_data;
  logic write_enable;

  logic [HWIDTH-1:0] output_hcount_pipe[0:1];
  logic [VWIDTH-1:0] output_vcount_pipe[0:1];
  logic output_data_valid_pipe[0:1];

  logic [HWIDTH-1:0] input_hcount_pipe[0:1];
  logic [VWIDTH-1:0] input_vcount_pipe[0:1];
  logic input_data_valid_pipe[0:1];
  logic pixel_in_pipe[0:1];
  logic [DWIDTH-1:0] prev_valid_pixel_distance;

  logic doing_backward_pass;
  logic [HWIDTH-1:0] backward_hcount;
  logic [VWIDTH-1:0] backward_vcount;
  logic [HWIDTH-1:0] backward_hcount_pipe[0:1];
  logic [VWIDTH-1:0] backward_vcount_pipe[0:1];
  logic backward_valid_pipe[0:1];
  logic [1:0] line_buff_weebs;
  logic [DWIDTH-1:0] backward_line_buff_data[0:1];
  logic [DWIDTH-1:0] prev_backward_pixel_distance;

  logic [DWIDTH-1:0] real_read_data, real_prev_pixel_distance;
  logic [DWIDTH-1:0] real_line_buff_data, real_backward_prev_pixel_distance;
  always_comb begin
    if (pixel_valid_in) begin
      read_addr = (pixel_vcount_in - 1) * HRES + pixel_hcount_in;
    end else if (doing_backward_pass) begin
      read_addr = backward_vcount * HRES + backward_hcount;
    end else begin
      read_addr = vcount_in * HRES + hcount_in;
    end
    if (input_data_valid_pipe[1]) begin
      write_addr = input_vcount_pipe[1] * HRES + input_hcount_pipe[1];
      real_read_data = input_vcount_pipe[1] == 0 ? INF : read_data;
      real_prev_pixel_distance = input_hcount_pipe[1] == 0 ? INF : prev_valid_pixel_distance;
      if (pixel_in_pipe[1]) begin
        write_data = 0;
      end else if (real_prev_pixel_distance == INF && real_read_data == INF) begin
        write_data = INF;
      end else begin
        write_data = real_prev_pixel_distance < real_read_data ? real_prev_pixel_distance + 1 : real_read_data + 1;
      end
      write_enable = 1;
    end else if (backward_valid_pipe[1]) begin
      write_addr = backward_vcount_pipe[1] * HRES + backward_hcount_pipe[1];
      if (backward_vcount_pipe[1] == VRES - 1) begin
        real_line_buff_data = INF;
      end else if (line_buff_weebs == 2'b01) begin
        real_line_buff_data = backward_line_buff_data[0];
      end else begin
        real_line_buff_data = backward_line_buff_data[1];
      end
      real_backward_prev_pixel_distance = backward_hcount_pipe[1] == HRES - 1 ? INF : prev_backward_pixel_distance;
      if (read_data == INF && real_line_buff_data == INF && real_backward_prev_pixel_distance == INF) begin
        write_data = INF;
      end else if (read_data < real_line_buff_data && read_data < real_backward_prev_pixel_distance) begin
        write_data = read_data + 1;
      end else if (real_line_buff_data < read_data && real_line_buff_data < real_backward_prev_pixel_distance) begin
        write_data = real_line_buff_data + 1;
      end else begin
        write_data = real_backward_prev_pixel_distance + 1;
      end
      write_enable = 1;
    end else begin
      write_enable = 0;
    end
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      output_data_valid_pipe[0] <= 0;
      output_data_valid_pipe[1] <= 0;
      prev_valid_pixel_distance <= INF;
      input_data_valid_pipe[0] <= 0;
      input_data_valid_pipe[1] <= 0;
      backward_valid_pipe[0] <= 0;
      backward_valid_pipe[1] <= 0;
    end else begin
      // Logic for when we're not inputting a new skeleton
      output_data_valid_pipe[0] <= !pixel_valid_in;
      output_data_valid_pipe[1] <= output_data_valid_pipe[0];
      output_hcount_pipe[0] <= hcount_in;
      output_hcount_pipe[1] <= output_hcount_pipe[0];
      output_vcount_pipe[0] <= vcount_in;
      output_vcount_pipe[1] <= output_vcount_pipe[0];
      hcount_out <= output_hcount_pipe[1];
      vcount_out <= output_vcount_pipe[1];
      data_valid_out <= output_data_valid_pipe[1];
      distance_out <= read_data;
      // Logic for when we're inputting a new skeleton
      input_hcount_pipe[0] <= pixel_hcount_in;
      input_hcount_pipe[1] <= input_hcount_pipe[0];
      input_vcount_pipe[0] <= pixel_vcount_in;
      input_vcount_pipe[1] <= input_vcount_pipe[0];
      pixel_in_pipe[0] <= pixel_in;
      pixel_in_pipe[1] <= pixel_in_pipe[0];
      input_data_valid_pipe[0] <= pixel_valid_in;
      input_data_valid_pipe[1] <= input_data_valid_pipe[0];
      if (input_data_valid_pipe[1]) begin
        prev_valid_pixel_distance <= write_data;
      end
      // When we're done with the forward pass, start the backward pass
      if (input_data_valid_pipe[1] && input_hcount_pipe[1] == HRES - 1 && input_vcount_pipe[1] == VRES - 1) begin
        doing_backward_pass <= 1;
        backward_hcount <= HRES - 1;
        backward_vcount <= VRES - 1;
        line_buff_weebs <= 2'b01;
      end
      // Update hcount and vcount for the backward pass
      if (doing_backward_pass) begin
        if (backward_hcount == 0) begin
          if (backward_vcount == 0) begin
            doing_backward_pass <= 0;
            backward_valid_pipe[0] <= 0;
          end else begin
            backward_vcount <= backward_vcount - 1;
            backward_hcount <= HRES - 1;
            backward_valid_pipe[0] <= 1;
            line_buff_weebs <= {line_buff_weebs[0], line_buff_weebs[1]};
          end
        end else begin
          backward_hcount <= backward_hcount - 1;
          backward_valid_pipe[0] <= 1;
        end
      end
      backward_hcount_pipe[0] <= backward_hcount;
      backward_hcount_pipe[1] <= backward_hcount_pipe[0];
      backward_vcount_pipe[0] <= backward_vcount;
      backward_vcount_pipe[1] <= backward_vcount_pipe[0];
      backward_valid_pipe[1]  <= backward_valid_pipe[0];
      if (backward_valid_pipe[1]) begin
        if (line_buff_weebs == 2'b01) begin
          prev_backward_pixel_distance <= backward_line_buff_data[0];
        end else begin
          prev_backward_pixel_distance <= backward_line_buff_data[1];
        end
      end
    end
  end

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .RAM_WIDTH(DWIDTH),
      .RAM_DEPTH(HRES * VRES)
  ) distance_ram (
      .addra(write_addr),
      .addrb(read_addr),
      .dina(write_data),
      .dinb(),
      .clka(clk_in),
      .wea(write_enable),
      .web(1'b0),
      .ena(1'b1),
      .enb(1'b1),
      .rsta(rst_in),
      .rstb(rst_in),
      .regcea(1'b1),
      .regceb(1'b1),
      .douta(),
      .doutb(read_data)
  );

  generate
    genvar i;
    for (i = 0; i < 2; i++) begin
      xilinx_true_dual_port_read_first_1_clock_ram #(
          .RAM_WIDTH(DWIDTH),
          .RAM_DEPTH(HRES)
      ) line_buffer (
          .addra(backward_hcount_pipe[1]),
          .addrb(backward_hcount),
          .dina(write_data),
          .dinb(),
          .clka(clk_in),
          .wea(line_buff_weebs[i] && backward_valid_pipe[1]),
          .web(1'b0),
          .ena(1'b1),
          .enb(1'b1),
          .rsta(rst_in),
          .rstb(rst_in),
          .regcea(1'b1),
          .regceb(1'b1),
          .douta(),
          .doutb(backward_line_buff_data[i])
      );
    end
  endgenerate
endmodule
