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

  logic [HWIDTH-1:0] iter_hcount;
  logic [VWIDTH-1:0] iter_vcount;
  logic iter_changed;
  logic iter_parity;
  logic [ADDR_WIDTH-1:0] write_addr;
  logic write_data;
  logic frame_buffer_out;

  logic [2:0][0:0] line_buffer_out;
  logic [2:0] line_buffer_buf[0:2];
  logic [HWIDTH-1:0] line_buffer_hcount;
  logic [VWIDTH-1:0] line_buffer_vcount;
  logic line_buffer_valid;
  logic [HWIDTH-1:0] line_buf_hcount_pipe;
  logic [VWIDTH-1:0] line_buf_vcount_pipe;

  logic outputting;

  logic [3:0] count_a, count_b;
  always_comb begin
    if (outputting) begin
    end else if (busy) begin
      write_addr = line_buf_vcount_pipe * HORIZONTAL_COUNT + line_buf_hcount_pipe;
      if (line_buf_hcount_pipe == 0 || line_buf_hcount_pipe == HORIZONTAL_COUNT - 1 ||
          line_buf_vcount_pipe == 0 || line_buf_vcount_pipe == VERTICAL_COUNT - 1) begin
        write_data = 0;
      end else begin
        count_b = line_buffer_buf[0][0] + line_buffer_buf[0][1] + line_buffer_buf[0][2]
                  + line_buffer_buf[1][0] + line_buffer_buf[1][2]
                  + line_buffer_buf[2][0] + line_buffer_buf[2][1] + line_buffer_buf[2][2];
        count_a = (!line_buffer_buf[0][0] & line_buffer_buf[0][1]) + (!line_buffer_buf[0][1] & line_buffer_buf[0][2])
                  + (!line_buffer_buf[0][2] & line_buffer_buf[1][2]) + (!line_buffer_buf[1][2] & line_buffer_buf[2][2])
                  + (!line_buffer_buf[2][2] & line_buffer_buf[2][1]) + (!line_buffer_buf[2][1] & line_buffer_buf[2][0])
                  + (!line_buffer_buf[2][0] & line_buffer_buf[1][0]) + (!line_buffer_buf[1][0] & line_buffer_buf[0][0]);
        if (count_b >= 2 && count_b <= 6 && count_a == 1 &&
            (iter_parity && !(line_buffer_buf[0][1] & line_buffer_buf[1][2] & line_buffer_buf[2][1])
                         && !(line_buffer_buf[0][1] & line_buffer_buf[2][1] & line_buffer_buf[1][0])
            || !iter_parity && !(line_buffer_buf[0][1] & line_buffer_buf[1][2] & line_buffer_buf[1][0])
                            && !(line_buffer_buf[0][1] & line_buffer_buf[2][1] & line_buffer_buf[1][0]))) begin
          write_data = 0;
        end else begin
          write_data = line_buffer_buf[1][1];
        end
      end
    end else begin
      write_addr = vcount_in * HORIZONTAL_COUNT + hcount_in;
      write_data = pixel_in;
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
    end else begin
      if (line_buffer_valid) begin
        line_buffer_buf[0]   <= line_buffer_buf[1];
        line_buffer_buf[1]   <= line_buffer_buf[2];
        line_buffer_buf[2]   <= line_buffer_out;
        line_buf_hcount_pipe <= line_buffer_hcount;
        line_buf_vcount_pipe <= line_buffer_vcount;
      end
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
              outputting <= 0;
            end else if (!iter_changed) begin
              outputting <= 1;
            end else begin
              iter_vcount  <= 0;
              iter_parity  <= ~iter_parity;
              iter_changed <= 0;
            end
          end else begin
            iter_vcount <= iter_vcount + 1;
          end
          iter_hcount <= 0;
        end else begin
          iter_hcount <= iter_hcount + 1;
        end
      end
      if (outputting) begin
        skeleton_out <= frame_buffer_out;
        hcount_out   <= iter_hcount;
        vcount_out   <= iter_vcount;
      end else begin
        skeleton_out <= 0;
        hcount_out   <= hcount_in;
        vcount_out   <= vcount_in;
      end
    end
  end

  line_buffer #(
      .HRES(HORIZONTAL_COUNT),
      .VRES(VERTICAL_COUNT),
      .DATA_WIDTH(1)
  ) lb (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .hcount_in(iter_hcount),
      .vcount_in(iter_vcount),
      .pixel_data_in(frame_buffer_out),
      .data_valid_in(busy),
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
      .wea(busy || pixel_valid_in),  // Port A write enable
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
