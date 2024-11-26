`timescale 1ns / 1ps `default_nettype none

module skeletonizer #(
    parameter int HORIZONTAL_COUNT = 320,
    parameter int VERTICAL_COUNT   = 180
) (
    input wire clk_in,
    input wire rst_in,
    input wire [HWIDTH-1:0] hcount_in,
    input wire [VWIDTH-1:0] vcount_in,
    input wire pixel_in,
    input wire pixel_valid_in,
    output logic skeleton_out,
    output logic [HWIDTH-1:0] hcount_out,
    output logic [VWIDTH-1:0] vcount_out,
    output logic pixel_valid_out,
    output logic busy
);
  localparam int HWIDTH = $clog2(HORIZONTAL_COUNT);
  localparam int VWIDTH = $clog2(VERTICAL_COUNT);
  localparam int ADDR_WIDTH = $clog2(HORIZONTAL_COUNT * VERTICAL_COUNT);

  // iter_hcount and iter_vcount help keep track of 
  logic [HWIDTH-1:0] iter_hcount;
  logic [VWIDTH-1:0] iter_vcount;
  logic iter_changed;
  logic iter_parity;
  logic [ADDR_WIDTH-1:0] write_addr;
  logic write_data;
  logic iter_wea;
  logic frame_buffer_out;

  // uses a line_buffer module to get 3 lines read at a time
  // need a 3x3 sqaure to compute neighbors and such, this is stored in line_buffer_buf
  //
  // the paritcular pixel we want to analyze has line_buffer_hcount/vcount

  logic [2:0][0:0] line_buffer_out;
  logic [2:0] line_buffer_buf[0:2];
  logic [HWIDTH-1:0] line_buffer_hcount;
  logic [VWIDTH-1:0] line_buffer_vcount;
  logic line_buffer_valid;
  logic [HWIDTH-1:0] line_buf_hcount_pipe[0:1];
  logic [VWIDTH-1:0] line_buf_vcount_pipe[0:1];
  logic line_buf_valid_pipe[0:1];

  logic [2:0] debug1, debug2, debug3;
  assign debug1 = line_buffer_buf[0];
  assign debug2 = line_buffer_buf[1];
  assign debug3 = line_buffer_buf[2];

  logic outputting;
  logic outputting_pipe[0:1];  // outputting once algorithm is finished with last iteration

  logic [3:0] count_a, count_b;

  always_comb begin
    if (outputting) begin
      iter_wea = 0;
    end else if (busy) begin
      write_addr = line_buf_vcount_pipe[1] * HORIZONTAL_COUNT + line_buf_hcount_pipe[1];
      // EDGE CASES HERE -- IF PIXEL IS ON EDGE OF SCREEN WE REMOVE IT
      if (line_buf_hcount_pipe[1] == 0 || line_buf_hcount_pipe[1] == HORIZONTAL_COUNT - 1 ||
          line_buf_vcount_pipe[1] == 0 || line_buf_vcount_pipe[1] == VERTICAL_COUNT - 1) begin
        write_data = 0;

      end else begin
        // MAIN PART OF ALGOIRTHM HERE: IF b and a satisfy certain conditions w/ iter_parity
        // then REMOVE pixel (write_data = 0). Crucial to make sure the write_data is aligned
        // with the acutal pixel we want to remove.
        //
        // count_b = number of positive neighbors surrounding [1][1]

        count_b = line_buffer_buf[0][0] + line_buffer_buf[0][1] + line_buffer_buf[0][2]
                  + line_buffer_buf[1][0] + line_buffer_buf[1][2]
                  + line_buffer_buf[2][0] + line_buffer_buf[2][1] + line_buffer_buf[2][2];

        // count_a = number of transitions from 0 to 1 or 1 to 0 when going in a circle
        // around pixel [1][1]

        count_a = (!line_buffer_buf[0][0] & line_buffer_buf[0][1]) + (!line_buffer_buf[0][1] & line_buffer_buf[0][2])
                  + (!line_buffer_buf[0][2] & line_buffer_buf[1][2]) + (!line_buffer_buf[1][2] & line_buffer_buf[2][2])
                  + (!line_buffer_buf[2][2] & line_buffer_buf[2][1]) + (!line_buffer_buf[2][1] & line_buffer_buf[2][0])
                  + (!line_buffer_buf[2][0] & line_buffer_buf[1][0]) + (!line_buffer_buf[1][0] & line_buffer_buf[0][0]);

        if (count_b >= 2 && count_b <= 6 && count_a == 1 &&
            (!iter_parity && !(line_buffer_buf[0][1] & line_buffer_buf[1][2] & line_buffer_buf[2][1])
                         && !(line_buffer_buf[1][2] & line_buffer_buf[2][1] & line_buffer_buf[1][0])
            || iter_parity && !(line_buffer_buf[0][1] & line_buffer_buf[1][2] & line_buffer_buf[1][0])
                            && !(line_buffer_buf[0][1] & line_buffer_buf[2][1] & line_buffer_buf[1][0]))) begin
          write_data = 0;
        end else begin
          write_data = line_buffer_buf[1][1];
        end
      end
      iter_wea = line_buf_valid_pipe[1];
      // so if the piped line_buffer data is valid, we can write to the frame_buffer
    end else begin
      write_addr = vcount_in * HORIZONTAL_COUNT + hcount_in;
      write_data = pixel_in;
      iter_wea   = pixel_valid_in;
    end
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      hcount_out <= 0;
      vcount_out <= 0;
      pixel_valid_out <= 0;
      busy <= 0;
      iter_hcount <= 0;
      iter_vcount <= 0;
      iter_changed <= 0;
      iter_parity <= 0;
      outputting <= 0;
      line_buffer_buf[0] <= 0;
      line_buffer_buf[1] <= 0;
      line_buffer_buf[2] <= 0;
      line_buf_hcount_pipe[0] <= 0;
      line_buf_hcount_pipe[1] <= 0;
      line_buf_vcount_pipe[0] <= 0;
      line_buf_vcount_pipe[1] <= 0;
      line_buf_valid_pipe[0] <= 0;
      line_buf_valid_pipe[1] <= 0;
      outputting_pipe[0] <= 0;
      outputting_pipe[1] <= 0;
    end else begin
      if (line_buffer_valid) begin  // pipeline here
        line_buffer_buf[0] <= line_buffer_buf[1];
        line_buffer_buf[1] <= line_buffer_buf[2];
        line_buffer_buf[2] <= line_buffer_out;
        line_buf_hcount_pipe[0] <= line_buffer_hcount;
        line_buf_hcount_pipe[1] <= line_buf_hcount_pipe[0];
        line_buf_vcount_pipe[0] <= line_buffer_vcount;
        line_buf_vcount_pipe[1] <= line_buf_vcount_pipe[0];
      end
      line_buf_valid_pipe[0] <= line_buffer_valid;
      line_buf_valid_pipe[1] <= line_buf_valid_pipe[0];

      // If we've just inputted the last pixel of the frame, we can start
      // iterating
      if (!busy && pixel_valid_in &&
          hcount_in == HORIZONTAL_COUNT - 1 && vcount_in == VERTICAL_COUNT - 1) begin
        busy <= 1;
        iter_hcount <= 0;
        iter_vcount <= 0;
        iter_parity <= 0;
        iter_changed <= 0;
        outputting <= 0;
      end

      if (busy) begin
        if (iter_hcount == HORIZONTAL_COUNT - 1) begin
          if (iter_vcount == VERTICAL_COUNT - 1) begin
            if (outputting) begin
              busy <= 0;
            end else if (!iter_changed) begin
              outputting <= 1;
            end else begin
              iter_parity  <= ~iter_parity;
              iter_changed <= 0;
            end
            iter_vcount <= 0;
          end else begin
            iter_vcount <= iter_vcount + 1;
          end
          iter_hcount <= 0;
        end else begin
          iter_hcount <= iter_hcount + 1;
        end
        if (write_data != line_buffer_buf[1][1]) begin
          iter_changed <= 1;
        end
      end
      outputting_pipe[0] <= outputting;
      outputting_pipe[1] <= outputting_pipe[0];
      if (outputting) begin
        skeleton_out <= frame_buffer_out;
        hcount_out <= iter_hcount_pipe[1];
        vcount_out <= iter_vcount_pipe[1];
        pixel_valid_out <= outputting_pipe[1];
        if (iter_vcount_pipe[1] == VERTICAL_COUNT - 1 &&
            iter_hcount_pipe[1] == HORIZONTAL_COUNT - 1 && outputting_pipe[1]) begin
          outputting <= 0;
        end
      end else begin
        pixel_valid_out <= 0;
      end
    end
  end

  logic [HWIDTH-1:0] iter_hcount_pipe[0:1];
  logic [VWIDTH-1:0] iter_vcount_pipe[0:1];
  logic line_buf_valid_in_pipe[0:1];

  // piping the iter logics for line_buffer
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      for (int i = 0; i < 2; i++) begin
        iter_hcount_pipe[i] <= 0;
        iter_vcount_pipe[i] <= 0;
        line_buf_valid_in_pipe[i] <= 0;
      end
    end else begin
      iter_hcount_pipe[0] <= iter_hcount;
      iter_hcount_pipe[1] <= iter_hcount_pipe[0];
      iter_vcount_pipe[0] <= iter_vcount;
      iter_vcount_pipe[1] <= iter_vcount_pipe[0];
      line_buf_valid_in_pipe[0] <= busy;
      line_buf_valid_in_pipe[1] <= line_buf_valid_in_pipe[0];
    end
  end

  line_buffer #(
      .HRES(HORIZONTAL_COUNT),
      .VRES(VERTICAL_COUNT),
      .DATA_WIDTH(1)
  ) lb (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .hcount_in(iter_hcount_pipe[1]),
      .vcount_in(iter_vcount_pipe[1]),
      .pixel_data_in(frame_buffer_out),
      .data_valid_in(line_buf_valid_in_pipe[1]),
      .line_buffer_out(line_buffer_out),
      .hcount_out(line_buffer_hcount),
      .vcount_out(line_buffer_vcount),
      .data_valid_out(line_buffer_valid)
  );

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .RAM_WIDTH(1),
      .RAM_DEPTH(HORIZONTAL_COUNT * VERTICAL_COUNT),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  ) frame_buffer (
      .clka(clk_in),  // Clock
      //writing port:
      .addra(write_addr),  // Port A address bus,
      .dina(write_data),  // Port A RAM input data
      .wea(iter_wea || pixel_valid_in),  // Port A write enable
      //reading port:
      .addrb(iter_vcount * HORIZONTAL_COUNT + iter_hcount),  // Port B address bus,
      .doutb(frame_buffer_out),  // Port B RAM output data,
      .douta(),  // Port A RAM output data, width determined from RAM_WIDTH
      .dinb(0),  // Port B RAM input data, width determined from RAM_WIDTH
      .web(1'b0),  // Port B write enable
      .ena(1'b1),  // Port A RAM Enable
      .enb(1'b1),  // Port B RAM Enable,
      .rsta(1'b0),  // Port A output reset
      .rstb(1'b0),  // Port B output reset
      .regcea(1'b1),  // Port A output register enable
      .regceb(1'b1)  // Port B output register enable
  );
endmodule

`default_nettype wire
