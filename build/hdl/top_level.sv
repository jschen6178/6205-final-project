`timescale 1ns / 1ps `default_nettype none

module top_level (
    input  wire         clk_100mhz,
    output logic [15:0] led,
    // camera bus
    input  wire  [ 7:0] camera_d,      // 8 parallel data wires
    output logic        cam_xclk,      // XC driving camera
    input  wire         cam_hsync,     // camera hsync wire
    input  wire         cam_vsync,     // camera vsync wire
    input  wire         cam_pclk,      // camera pixel clock
    inout  wire         i2c_scl,       // i2c inout clock
    inout  wire         i2c_sda,       // i2c inout data
    input  wire  [15:0] sw,
    input  wire  [ 3:0] btn,
    output logic [ 2:0] rgb0,
    output logic [ 2:0] rgb1,
    // seven segment
    output logic [ 3:0] ss0_an,        //anode control for upper four digits of seven-seg display
    output logic [ 3:0] ss1_an,        //anode control for lower four digits of seven-seg display
    output logic [ 6:0] ss0_c,         //cathode controls for the segments of upper four digits
    output logic [ 6:0] ss1_c,         //cathod controls for the segments of lower four digits
    // hdmi port
    output logic [ 2:0] hdmi_tx_p,     //hdmi output signals (positives) (blue, green, red)
    output logic [ 2:0] hdmi_tx_n,     //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p,
    hdmi_clk_n,  //differential hdmi clock
    // New for week 6: DDR3 ports
    inout  wire  [15:0] ddr3_dq,
    inout  wire  [ 1:0] ddr3_dqs_n,
    inout  wire  [ 1:0] ddr3_dqs_p,
    output wire  [12:0] ddr3_addr,
    output wire  [ 2:0] ddr3_ba,
    output wire         ddr3_ras_n,
    output wire         ddr3_cas_n,
    output wire         ddr3_we_n,
    output wire         ddr3_reset_n,
    output wire         ddr3_ck_p,
    output wire         ddr3_ck_n,
    output wire         ddr3_cke,
    output wire  [ 1:0] ddr3_dm,
    output wire         ddr3_odt
);

  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;

  // Clock and Reset Signals: updated for a couple new clocks!
  logic sys_rst_camera;
  logic sys_rst_pixel;
  
  logic clk_camera;
  logic clk_pixel;
  logic clk_5x;
  logic clk_xc;


  logic clk_migref;
  logic sys_rst_migref;

  logic clk_ui;
  logic sys_rst_ui;

  logic clk_100_passthrough;

  // clocking wizards to generate the clock speeds we need for our different domains
  // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
  cw_hdmi_clk_wiz wizard_hdmi (
      .sysclk(clk_100_passthrough),
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(0)
  );

  cw_fast_clk_wiz wizard_migcam (
      .clk_in1(clk_100mhz),
      .clk_camera(clk_camera),
      .clk_mig(clk_migref),
      .clk_xc(clk_xc),
      .clk_100(clk_100_passthrough),
      .reset(0)
  );

  // assign camera's xclk to pmod port: drive the operating clock of the camera!
  // this port also is specifically set to high drive by the XDC file.
  assign cam_xclk = clk_xc;

  assign sys_rst_camera = btn[0];  //use for resetting camera side of logic
  assign sys_rst_pixel = btn[0];  //use for resetting hdmi/draw side of logic
  assign sys_rst_migref = btn[0];

  // video signal generator signals
  logic        hsync_hdmi;
  logic        vsync_hdmi;
  logic [10:0] hcount_hdmi;
  logic [ 9:0] vcount_hdmi;
  logic        active_draw_hdmi;
  logic        new_frame_hdmi;
  logic [ 5:0] frame_count_hdmi;
  logic        nf_hdmi;

  // rgb output values
  logic [7:0] red, green, blue;

  // ** Handling input from the camera **

  // synchronizers to prevent metastability
  logic [7:0] camera_d_buf [1:0];
  logic       cam_hsync_buf[1:0];
  logic       cam_vsync_buf[1:0];
  logic       cam_pclk_buf [1:0];

  always_ff @(posedge clk_camera) begin
    camera_d_buf[1]  <= camera_d;
    camera_d_buf[0]  <= camera_d_buf[1];
    cam_pclk_buf[1]  <= cam_pclk;
    cam_pclk_buf[0]  <= cam_pclk_buf[1];
    cam_hsync_buf[1] <= cam_hsync;
    cam_hsync_buf[0] <= cam_hsync_buf[1];
    cam_vsync_buf[1] <= cam_vsync;
    cam_vsync_buf[0] <= cam_vsync_buf[1];
  end

  logic [10:0] camera_hcount;
  logic [ 9:0] camera_vcount;
  logic [15:0] camera_pixel;
  logic        camera_valid;

  // your pixel_reconstruct module, from the exercise!
  // hook it up to buffered inputs.
  pixel_reconstruct pixel_reconstruct_inst (
      .clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .camera_pclk_in(cam_pclk_buf[0]),
      .camera_hs_in(cam_hsync_buf[0]),
      .camera_vs_in(cam_vsync_buf[0]),
      .camera_data_in(camera_d_buf[0]),
      .pixel_valid_out(camera_valid),
      .pixel_hcount_out(camera_hcount),
      .pixel_vcount_out(camera_vcount),
      .pixel_data_out(camera_pixel)
  );


  // 2. The New Way: write memory to DRAM and read it out, over a couple AXI-Stream data pipelines.
  // NEW DRAM STUFF STARTS HERE


  logic [127:0] camera_chunk;
  logic [127:0] camera_axis_tdata;
  logic         camera_axis_tlast;
  logic         camera_axis_tready;
  logic         camera_axis_tvalid;

  // takes our 16-bit values and deserialize/stack them into 128-bit messages to write to DRAM
  // the data pipeline is designed such that we can fairly safely assume its always ready.
  stacker stacker_inst (
      .clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .pixel_tvalid(camera_valid),
      .pixel_tready(),
      .pixel_tdata(camera_pixel),
      .pixel_tlast(camera_hcount == 1279 && camera_vcount == 719),
      .chunk_tvalid(camera_axis_tvalid),
      .chunk_tready(camera_axis_tready),
      .chunk_tdata(camera_axis_tdata),
      .chunk_tlast(camera_axis_tlast)
  );

  logic [127:0] camera_ui_axis_tdata;
  logic         camera_ui_axis_tlast;
  logic         camera_ui_axis_tready;
  logic         camera_ui_axis_tvalid;
  logic         camera_ui_axis_prog_empty;

  // FIFO data queue of 128-bit messages, crosses clock domains to the 81.25MHz
  // UI clock of the memory interface
  ddr_fifo_wrap camera_data_fifo (
      .sender_rst(sys_rst_camera),
      .sender_clk(clk_camera),
      .sender_axis_tvalid(camera_axis_tvalid),
      .sender_axis_tready(camera_axis_tready),
      .sender_axis_tdata(camera_axis_tdata),
      .sender_axis_tlast(camera_axis_tlast),
      .receiver_clk(clk_ui),
      .receiver_axis_tvalid(camera_ui_axis_tvalid),
      .receiver_axis_tready(camera_ui_axis_tready),
      .receiver_axis_tdata(camera_ui_axis_tdata),
      .receiver_axis_tlast(camera_ui_axis_tlast),
      .receiver_axis_prog_empty(camera_ui_axis_prog_empty)
  );

  logic [127:0] display_ui_axis_tdata;
  logic         display_ui_axis_tlast;
  logic         display_ui_axis_tready;
  logic         display_ui_axis_tvalid;
  logic         display_ui_axis_prog_full;

  // these are the signals that the MIG IP needs for us to define!
  // MIG UI --> generic outputs
  logic [ 26:0] app_addr;
  logic [  2:0] app_cmd;
  logic         app_en;
  // MIG UI --> write outputs
  logic [127:0] app_wdf_data;
  logic         app_wdf_end;
  logic         app_wdf_wren;
  logic [ 15:0] app_wdf_mask;
  // MIG UI --> read inputs
  logic [127:0] app_rd_data;
  logic         app_rd_data_end;
  logic         app_rd_data_valid;
  // MIG UI --> generic inputs
  logic         app_rdy;
  logic         app_wdf_rdy;
  // MIG UI --> misc
  logic         app_sr_req;
  logic         app_ref_req;
  logic         app_zq_req;
  logic         app_sr_active;
  logic         app_ref_ack;
  logic         app_zq_ack;
  logic         init_calib_complete;


  // this traffic generator handles reads and writes issued to the MIG IP,
  // which in turn handles the bus to the DDR chip.
  traffic_generator readwrite_looper (
      // Outputs
      .app_addr            (app_addr[26:0]),
      .app_cmd             (app_cmd[2:0]),
      .app_en              (app_en),
      .app_wdf_data        (app_wdf_data[127:0]),
      .app_wdf_end         (app_wdf_end),
      .app_wdf_wren        (app_wdf_wren),
      .app_wdf_mask        (app_wdf_mask[15:0]),
      .app_sr_req          (app_sr_req),
      .app_ref_req         (app_ref_req),
      .app_zq_req          (app_zq_req),
      .write_axis_ready    (camera_ui_axis_tready),
      .read_axis_data      (display_ui_axis_tdata),
      .read_axis_tlast     (display_ui_axis_tlast),
      .read_axis_valid     (display_ui_axis_tvalid),
      // Inputs
      .clk_in              (clk_ui),
      .rst_in              (sys_rst_ui),
      .app_rd_data         (app_rd_data[127:0]),
      .app_rd_data_end     (app_rd_data_end),
      .app_rd_data_valid   (app_rd_data_valid),
      .app_rdy             (app_rdy),
      .app_wdf_rdy         (app_wdf_rdy),
      .app_sr_active       (app_sr_active),
      .app_ref_ack         (app_ref_ack),
      .app_zq_ack          (app_zq_ack),
      .init_calib_complete (init_calib_complete),
      .write_axis_data     (camera_ui_axis_tdata),
      .write_axis_tlast    (camera_ui_axis_tlast),
      .write_axis_valid    (camera_ui_axis_tvalid),
      .write_axis_smallpile(camera_ui_axis_prog_empty),
      .read_axis_af        (display_ui_axis_prog_full),
      .read_axis_ready     (display_ui_axis_tready)      //,
  );

  // the MIG IP!
  ddr3_mig ddr3_mig_inst (
      .ddr3_dq(ddr3_dq),
      .ddr3_dqs_n(ddr3_dqs_n),
      .ddr3_dqs_p(ddr3_dqs_p),
      .ddr3_addr(ddr3_addr),
      .ddr3_ba(ddr3_ba),
      .ddr3_ras_n(ddr3_ras_n),
      .ddr3_cas_n(ddr3_cas_n),
      .ddr3_we_n(ddr3_we_n),
      .ddr3_reset_n(ddr3_reset_n),
      .ddr3_ck_p(ddr3_ck_p),
      .ddr3_ck_n(ddr3_ck_n),
      .ddr3_cke(ddr3_cke),
      .ddr3_dm(ddr3_dm),
      .ddr3_odt(ddr3_odt),
      .sys_clk_i(clk_migref),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_wdf_data(app_wdf_data),
      .app_wdf_end(app_wdf_end),
      .app_wdf_wren(app_wdf_wren),
      .app_rd_data(app_rd_data),
      .app_rd_data_end(app_rd_data_end),
      .app_rd_data_valid(app_rd_data_valid),
      .app_rdy(app_rdy),
      .app_wdf_rdy(app_wdf_rdy),
      .app_sr_req(app_sr_req),
      .app_ref_req(app_ref_req),
      .app_zq_req(app_zq_req),
      .app_sr_active(app_sr_active),
      .app_ref_ack(app_ref_ack),
      .app_zq_ack(app_zq_ack),
      .ui_clk(clk_ui),
      .ui_clk_sync_rst(sys_rst_ui),
      .app_wdf_mask(app_wdf_mask),
      .init_calib_complete(init_calib_complete),
      // .device_temp(device_temp),
      .sys_rst(!sys_rst_migref)  // active low
  );

  logic [127:0] display_axis_tdata;
  logic         display_axis_tlast;
  logic         display_axis_tready;
  logic         display_axis_tvalid;
  logic         display_axis_prog_empty;

  ddr_fifo_wrap pdfifo (
      .sender_rst(sys_rst_ui),
      .sender_clk(clk_ui),
      .sender_axis_tvalid(display_ui_axis_tvalid),
      .sender_axis_tready(display_ui_axis_tready),
      .sender_axis_tdata(display_ui_axis_tdata),
      .sender_axis_tlast(display_ui_axis_tlast),
      .sender_axis_prog_full(display_ui_axis_prog_full),
      .receiver_clk(clk_pixel),
      .receiver_axis_tvalid(display_axis_tvalid),
      .receiver_axis_tready(display_axis_tready),
      .receiver_axis_tdata(display_axis_tdata),
      .receiver_axis_tlast(display_axis_tlast),
      .receiver_axis_prog_empty(display_axis_prog_empty)
  );

  logic        frame_buff_tvalid;
  logic        frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;

  unstacker unstacker_inst (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .chunk_tvalid(display_axis_tvalid),
      .chunk_tready(display_axis_tready),
      .chunk_tdata(display_axis_tdata),
      .chunk_tlast(display_axis_tlast),
      .pixel_tvalid(frame_buff_tvalid),
      .pixel_tready(frame_buff_tready),
      .pixel_tdata(frame_buff_tdata),
      .pixel_tlast(frame_buff_tlast)
  );

  // assign frame_buff_tready
  // I did this in 1 (kind of long) line. an always_comb block could also work.
  assign frame_buff_tready = frame_buff_tlast ? (hcount_hdmi == 1279 && vcount_hdmi == 719) : active_draw_hdmi;

  assign frame_buff_dram = frame_buff_tvalid ? frame_buff_tdata : 16'h2277;

  // NEW DRAM STUFF ENDS HERE: below here should look familiar from last week!

  //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
  //remapped frame_buffer outputs with 8 bits for r, g, b
  logic [7:0] fb_red, fb_green, fb_blue;
  always_ff @(posedge clk_pixel) begin
    fb_red   <= {frame_buff_dram[15:11], 3'b0};
    fb_green <= {frame_buff_dram[10:5], 2'b0};
    fb_blue  <= {frame_buff_dram[4:0], 3'b0};
  end
  // Pixel Processing pre-HDMI output

  // RGB to YCrCb

  //output of rgb to ycrcb conversion (10 bits due to module):
  logic [9:0] y_full, cr_full, cb_full;  //ycrcb conversion of full pixel
  //bottom 8 of y, cr, cb conversions:
  logic [7:0] y, cr, cb;  //ycrcb conversion of full pixel
  //Convert RGB of full pixel to YCrCb
  //See lecture 07 for YCrCb discussion.
  //Module has a 3 cycle latency
  rgb_to_ycrcb rgbtoycrcb_m (
      .clk_in(clk_pixel),
      .r_in  (fb_red),
      .g_in  (fb_green),
      .b_in  (fb_blue),
      .y_out (y_full),
      .cr_out(cr_full),
      .cb_out(cb_full)
  );

  //threshold module (apply masking threshold):
  logic [7:0] cr_cutoff;
  logic [7:0] y_cutoff;
  logic [7:0] cb_cutoff;
  logic       mask;  //Whether or not thresholded pixel is 1 or 0

  //take lower 8 of full outputs.
  // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
  assign y = y_full[7:0];
  assign cr = {!cr_full[7], cr_full[6:0]};
  assign cb = {!cb_full[7], cb_full[6:0]};

  //threshold values used to determine what value passes:
  assign cr_cutoff = {sw[11:8], 4'b0};
  assign y_cutoff = {sw[7:6], sw[3:1], 3'b0};
  assign cb_cutoff = {sw[15:12], 4'b0};

  //Thresholder: Takes in the full selected channedl and
  //based on upper and lower bounds provides a binary mask bit
  // * 1 if selected channel is within the bounds (inclusive)
  // * 0 if selected channel is not within the bounds
  threshold mt (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .y_in(y),
      .cr_in(cr),
      .cb_in(cb),
      .y_cutoff(y_cutoff),
      .cr_cutoff(cr_cutoff),
      .cb_cutoff(cb_cutoff),
      .mask_out(mask)  //single bit if pixel within mask.
  );

  // Skeletonization logic

  logic [8:0] binner_hcount;
  logic [7:0] binner_vcount;
  logic       binner_pixel;
  logic       binner_valid;

  binning_2 binner (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .hcount_in(hcount_hdmi),
      .vcount_in(vcount_hdmi),
      .pixel_data_in(mask),
      .data_valid_in(frame_buff_tvalid && frame_buff_tready),
      .pixel_data_out(binner_pixel),
      .hcount_out(binner_hcount),
      .vcount_out(binner_vcount),
      .data_valid_out(binner_valid)
  );

  logic [8:0] skeleton_hcount;
  logic [7:0] skeleton_vcount;
  logic       skeleton_pixel;
  logic       skeleton_valid;
  logic       skeleton_busy;
  logic       should_input_skeleton;

  always_ff @(posedge clk_pixel) begin
    if (sys_rst_pixel) begin
      should_input_skeleton <= 0;
    end else begin
      if (!skeleton_busy && binner_hcount == 319 && binner_vcount == 179 && binner_valid) begin
        should_input_skeleton <= 1;
      end else if (skeleton_busy) begin
        should_input_skeleton <= 0;
      end
    end
  end

  skeletonizer skeletonizer_inst (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .hcount_in(binner_hcount),
      .vcount_in(binner_vcount),
      .pixel_in(binner_pixel),
      .pixel_valid_in(sw[0] && binner_valid && should_input_skeleton),
      .skeleton_out(skeleton_pixel),
      .pixel_valid_out(skeleton_valid),
      .hcount_out(skeleton_hcount),
      .vcount_out(skeleton_vcount),
      .busy(skeleton_busy)
  );
  logic reset_benchmark_skeleton;
  assign reset_benchmark_skeleton = btn[3]; // press this when you want a new benchmark pose

  
  logic skeleton_buf_out;
  logic [8:0] pixel_scorer_hcount_out;
  logic [7:0] pixel_scorer_vcount_out;
  logic [9:0] pixel_scorer_distance_out;
  logic pixel_scorer_valid_out;
  logic pixel_scorer_valid_in;

  // always_comb begin
  //   if (reset_benchmark_skeleton && skeleton_valid && skeleton_hcount == 0 && skeleton_vcount == 0) begin
  //     pixel_scorer_valid_in = 1;
  //   end else if (pixel_scorer_valid_in) begin
  //     pixel_scorer_valid_in = skeleton_valid;
  //   end
  // end

  always_ff @(posedge clk_pixel) begin
    if (sys_rst_pixel) pixel_scorer_valid_in <= 0;

    if (reset_benchmark_skeleton && skeleton_valid && skeleton_hcount == 0 && skeleton_vcount == 0) begin
      pixel_scorer_valid_in <= 1; 
    end else if (pixel_scorer_valid_in && skeleton_hcount == 319 && skeleton_vcount == 179) begin
      pixel_scorer_valid_in <= 0; 
    end
  end

  pixel_scorer pixel_scorer_inst (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .pixel_hcount_in(skeleton_hcount),
    .pixel_vcount_in(skeleton_vcount),
    .hcount_in(skeleton_hcount), // try this, see if it fixes it //justin @6:23pm monday
    .vcount_in(skeleton_vcount),
    .pixel_in(skeleton_pixel), // this might not work with the above hcount and vcount
    .pixel_valid_in(pixel_scorer_valid_in),
    .hcount_out(pixel_scorer_hcount_out),
    .vcount_out(pixel_scorer_vcount_out),
    .distance_out(pixel_scorer_distance_out),
    .data_valid_out(pixel_scorer_valid_out)
  );


  logic [2:0] skeleton_pixel_buffer;
  logic score_valid;
  logic [2:0] final_score;
  always_ff @(posedge clk_pixel) begin
    if (sys_rst_pixel) begin
      
    skeleton_pixel_buffer = 3'b0;
    end else begin

    skeleton_pixel_buffer[0] <= skeleton_pixel;
    skeleton_pixel_buffer[1] <= skeleton_pixel_buffer[0];
    skeleton_pixel_buffer[2] <= skeleton_pixel_buffer[1];
    end
  end
  scorer scorer_inst(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_in(pixel_scorer_hcount_out), // not really used just to get valid out
    .vcount_in(pixel_scorer_vcount_out), // this too
    .skeleton_bit(skeleton_pixel_buffer[2]),
    .pixel_distance(pixel_scorer_distance_out),
    .valid_in(pixel_scorer_valid_out),
    .valid_out(score_valid),
    .final_score(final_score)
  );

  logic [3:0] display_slow_count;

  evt_counter #(
    .MAX_COUNT(10)
    ) display_slower(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .evt_in(score_valid),
    .count_out(display_slow_count)
  );

  logic [2:0] display_final_score;
  always_ff @(posedge clk_pixel) begin
    if (sys_rst_pixel) display_final_score <= 0;
    else display_final_score <= (score_valid && display_slow_count == 0) ? final_score : display_final_score;
  end

  // TODO: store skeleton output in a frame buffer
  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(1),  // Specify RAM data width
      .RAM_DEPTH(320 * 180),  // Specify RAM depth (number of entries)
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  ) skeleton_frame_buffer (
      .addra(sw[0] ? (skeleton_vcount * 320 + skeleton_hcount) : (binner_vcount * 320 + binner_hcount)),  // Port A address bus, width determined from RAM_DEPTH
      .addrb(vcount_hdmi[9:2] * 320 + hcount_hdmi[10:2]),  // Port B address bus, width determined from RAM_DEPTH
      .dina(sw[0] ? skeleton_pixel : binner_pixel),  // Port A RAM input data, width determined from RAM_WIDTH
      .dinb(),  // Port B RAM input data, width determined from RAM_WIDTH
      .clka(clk_pixel),  // Port A clock
      .clkb(clk_pixel),  // Port B clock
      .wea(sw[0] ? skeleton_valid : binner_valid),  // Port A write enable
      .web(0),  // Port B write enable
      .ena(1'b1),  // Port A RAM Enable, for additional power savings, disable port when not in use
      .enb(1'b1),  // Port B RAM Enable, for additional power savings, disable port when not in use
      .rsta(sys_rst_pixel),  // Port A output reset (does not affect memory contents)
      .rstb(sys_rst_pixel),  // Port B output reset (does not affect memory contents)
      .regcea(1'b1),  // Port A output register enable
      .regceb(1'b1),  // Port B output register enable
      .douta(),  // Port A RAM output data, width determined from RAM_WIDTH
      .doutb(skeleton_buf_out)  // Port B RAM output data, width determined from RAM_WIDTH
  );

  logic benchmark_skeleton_buf_out;
  //below might need some pipelining
  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(1),  // Specify RAM data width
      .RAM_DEPTH(320 * 180),  // Specify RAM depth (number of entries)
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  ) benchmark_skeleton_frame_buffer (
      .addra(skeleton_vcount * 320 + skeleton_hcount),  // Port A address bus, width determined from RAM_DEPTH
      .addrb(vcount_hdmi[9:2] * 320 + hcount_hdmi[10:2]),  // Port B address bus, width determined from RAM_DEPTH
      .dina(skeleton_pixel),  // Port A RAM input data, width determined from RAM_WIDTH
      .dinb(),  // Port B RAM input data, width determined from RAM_WIDTH
      .clka(clk_pixel),  // Port A clock
      .clkb(clk_pixel),  // Port B clock
      .wea(pixel_scorer_valid_in),  // Port A write enable
      .web(0),  // Port B write enable
      .ena(1'b1),  // Port A RAM Enable, for additional power savings, disable port when not in use
      .enb(1'b1),  // Port B RAM Enable, for additional power savings, disable port when not in use
      .rsta(sys_rst_pixel),  // Port A output reset (does not affect memory contents)
      .rstb(sys_rst_pixel),  // Port B output reset (does not affect memory contents)
      .regcea(1'b1),  // Port A output register enable
      .regceb(1'b1),  // Port B output register enable
      .douta(),  // Port A RAM output data, width determined from RAM_WIDTH
      .doutb(benchmark_skeleton_buf_out)  // Port B RAM output data, width determined from RAM_WIDTH
  );
  // Frame buffer stuff (Try not to touch)

  logic [15:0] frame_buff_dram;  // data out of DRAM frame buffer

  logic [ 6:0] ss_c;
  //modified version of seven segment display for showing
  // thresholds and selected channel
  // special customized version
  seven_segment_display mssc (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      // .bin_in({y_cutoff, 4'b0, cr_cutoff, 4'b0, cb_cutoff}),
      .bin_in({
        3'b0,
        should_input_skeleton,
        3'b0,
        skeleton_busy,
        3'b0,
        skeleton_pixel,
        3'b0,
        skeleton_valid,
        skeleton_hcount[8:5],
        skeleton_vcount[7:4],
        8'b0
      }),
      .enable_in(8'b11111100),
      .cat_out(ss_c),
      .an_out({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c;  //control upper four digit's cathodes!
  assign ss1_c = ss_c;  //same as above but for lower four digits!
  
  logic score_pixel_valid_out;
  logic [7:0] score_red, score_green, score_blue;
  score_sprite_2 score_sp (
      .hcount_in(hcount_hdmi),
      .vcount_in(vcount_hdmi),
      .score(display_final_score),
      .score_pixel_valid_out(score_pixel_valid_out),
      .red_out(score_red),
      .green_out(score_green),
      .blue_out(score_blue)
  );
  // HDMI video signal generator
  video_sig_gen vsg (
      .pixel_clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .hcount_out(hcount_hdmi),
      .vcount_out(vcount_hdmi),
      .vs_out(vsync_hdmi),
      .hs_out(hsync_hdmi),
      .nf_out(nf_hdmi),
      .ad_out(active_draw_hdmi),
      .fc_out(frame_count_hdmi)
  );


  // Video Mux: select from the different display modes based on switch values
  //used with switches for display selections
  logic [1:0] display_choice;

  assign display_choice = sw[5:4];

  //choose what to display from the camera:
  // * 'b00:  normal camera out
  // * 'b01:  not implemented
  // * 'b10:  masked pixel (all on if 1, all off if 0)
  // * 'b11:  normal output with mask overtop as magenta

  video_mux mvm (
      .bg_in(display_choice),  //choose background
      .benchmark_skeleton_bit(benchmark_skeleton_buf_out),
      .bin_in(sw[4] ? (sw[0] ? skeleton_pixel & skeleton_valid : binner_pixel & binner_valid) : skeleton_buf_out),
      .camera_pixel_in(score_pixel_valid_out ? {score_red, score_green, score_blue} : {fb_red, fb_green, fb_blue}),
      .thresholded_pixel_in(mask),  //one bit mask signal
      .pixel_out({red, green, blue})  //output to tmds
  );

  // HDMI Output: just like before!

  logic [9:0] tmds_10b   [0:2];  //output of each TMDS encoder!
  logic       tmds_signal[2:0];  //output of each TMDS serializer!

  //three tmds_encoders (blue, green, red)
  //note green should have no control signal like red
  //the blue channel DOES carry the two sync signals:
  //  * control_in[0] = horizontal sync signal
  //  * control_in[1] = vertical sync signal

  tmds_encoder tmds_red (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[2])
  );

  tmds_encoder tmds_green (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .data_in(green),
      .control_in(2'b0),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[1])
  );

  tmds_encoder tmds_blue (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .data_in(blue),
      .control_in({vsync_hdmi, hsync_hdmi}),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[0])
  );


  //three tmds_serializers (blue, green, red):
  //MISSING: two more serializers for the green and blue tmds signals.
  tmds_serializer red_ser (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst_pixel),
      .tmds_in(tmds_10b[2]),
      .tmds_out(tmds_signal[2])
  );
  tmds_serializer green_ser (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst_pixel),
      .tmds_in(tmds_10b[1]),
      .tmds_out(tmds_signal[1])
  );
  tmds_serializer blue_ser (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst_pixel),
      .tmds_in(tmds_10b[0]),
      .tmds_out(tmds_signal[0])
  );

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals asserted
  //during blanking and sync periods to synchronize their faster bit clocks off
  //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
  //the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (
      .I (tmds_signal[0]),
      .O (hdmi_tx_p[0]),
      .OB(hdmi_tx_n[0])
  );
  OBUFDS OBUFDS_green (
      .I (tmds_signal[1]),
      .O (hdmi_tx_p[1]),
      .OB(hdmi_tx_n[1])
  );
  OBUFDS OBUFDS_red (
      .I (tmds_signal[2]),
      .O (hdmi_tx_p[2]),
      .OB(hdmi_tx_n[2])
  );
  OBUFDS OBUFDS_clock (
      .I (clk_pixel),
      .O (hdmi_clk_p),
      .OB(hdmi_clk_n)
  );


  // Nothing To Touch Down Here:
  // register writes to the camera

  // The OV5640 has an I2C bus connected to the board, which is used
  // for setting all the hardware settings (gain, white balance,
  // compression, image quality, etc) needed to start the camera up.
  // We've taken care of setting these all these values for you:
  // "rom.mem" holds a sequence of bytes to be sent over I2C to get
  // the camera up and running, and we've written a design that sends
  // them just after a reset completes.

  // If the camera is not giving data, press your reset button.

  logic busy, bus_active;
  logic cr_init_valid, cr_init_ready;

  logic recent_reset;
  always_ff @(posedge clk_camera) begin
    if (sys_rst_camera) begin
      recent_reset  <= 1'b1;
      cr_init_valid <= 1'b0;
    end else if (recent_reset) begin
      cr_init_valid <= 1'b1;
      recent_reset  <= 1'b0;
    end else if (cr_init_valid && cr_init_ready) begin
      cr_init_valid <= 1'b0;
    end
  end

  logic [23:0] bram_dout;
  logic [ 7:0] bram_addr;

  // ROM holding pre-built camera settings to send
  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(24),
      .RAM_DEPTH(256),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
      .INIT_FILE("rom.mem")
  ) registers (
      .addra(bram_addr),  // Address bus, width determined from RAM_DEPTH
      .dina(24'b0),  // RAM input data, width determined from RAM_WIDTH
      .clka(clk_camera),  // Clock
      .wea(1'b0),  // Write enable
      .ena(1'b1),  // RAM Enable, for additional power savings, disable port when not in use
      .rsta(sys_rst_camera),  // Output reset (does not affect memory contents)
      .regcea(1'b1),  // Output register enable
      .douta(bram_dout)  // RAM output data, width determined from RAM_WIDTH
  );

  logic [23:0] registers_dout;
  logic [ 7:0] registers_addr;
  assign registers_dout = bram_dout;
  assign bram_addr = registers_addr;

  logic con_scl_i, con_scl_o, con_scl_t;
  logic con_sda_i, con_sda_o, con_sda_t;

  // NOTE these also have pullup specified in the xdc file!
  // access our inouts properly as tri-state pins
  IOBUF IOBUF_scl (
      .I (con_scl_o),
      .IO(i2c_scl),
      .O (con_scl_i),
      .T (con_scl_t)
  );
  IOBUF IOBUF_sda (
      .I (con_sda_o),
      .IO(i2c_sda),
      .O (con_sda_i),
      .T (con_sda_t)
  );

  // provided module to send data BRAM -> I2C
  camera_registers crw (
      .clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .init_valid(cr_init_valid),
      .init_ready(cr_init_ready),
      .scl_i(con_scl_i),
      .scl_o(con_scl_o),
      .scl_t(con_scl_t),
      .sda_i(con_sda_i),
      .sda_o(con_sda_o),
      .sda_t(con_sda_t),
      .bram_dout(registers_dout),
      .bram_addr(registers_addr)
  );

  // a handful of debug signals for writing to registers
  assign led[0] = 0;
  assign led[1] = cr_init_valid;
  assign led[2] = cr_init_ready;
  assign led[15:3] = 0;

endmodule  // top_level


`default_nettype wire

