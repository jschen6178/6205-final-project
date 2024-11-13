`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct
	#(
	 parameter HCOUNT_WIDTH = 11,
	 parameter VCOUNT_WIDTH = 10
	 )
	(
	 input wire 										 clk_in,
	 input wire 										 rst_in,
	 input wire 										 camera_pclk_in,
	 input wire 										 camera_hs_in,
	 input wire 										 camera_vs_in,
	 input wire [7:0] 							 camera_data_in,
	 output logic 									 pixel_valid_out,
	 output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
	 output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
	 output logic [15:0] 						 pixel_data_out
	 );

	 // your code here! and here's a handful of logics that you may find helpful to utilize.
	 
	 // previous value of PCLK
	 logic 													 pclk_prev;

	 // can be assigned combinationally:
	 //  true when pclk transitions from 0 to 1
	 logic 													 camera_sample_valid;
	 assign camera_sample_valid = (~pclk_prev & camera_pclk_in); // TODO: fix this assign
	 
	 // previous value of camera data, from last valid sample!
	 // should NOT update on every cycle of clk_in, only
	 // when samples are valid.
	 logic 													 last_sampled_hs;
	 logic [7:0] 										 last_sampled_data;

	 // flag indicating whether the last byte has been transmitted or not.
	 logic 													 half_pixel_ready;
		typedef enum {IDLE, VALID, HSYNC, VSYNC} receive_state;

		receive_state state;

	 always_ff@(posedge clk_in) begin
			if (rst_in) begin
					pixel_valid_out <= 0;
					pixel_hcount_out <= 0;
					pixel_vcount_out <= 0;
					pixel_data_out <= 0;
					last_sampled_hs <= 0;
					last_sampled_data <= 0;
					half_pixel_ready <= 0;
					pclk_prev <= 0;

					state <= IDLE;
			end else begin
					pclk_prev <= camera_pclk_in;
				 if(camera_sample_valid) begin
						
						case(state)
							IDLE: begin // assume this is when we start transmitting
								if (camera_hs_in == 1 && camera_vs_in == 1) begin
									state <= VALID;
									last_sampled_data <= camera_data_in;
									half_pixel_ready <= 1;
								end
							end

							VALID: begin
								if (camera_hs_in == 1 && camera_vs_in == 1) begin
									case (half_pixel_ready)
										0: begin
											last_sampled_data <= camera_data_in;
											half_pixel_ready <= 1;
											pixel_valid_out <= 0;
											pixel_hcount_out <= pixel_hcount_out + 1; // only done once per 16 bits
										end

										1: begin
											last_sampled_data <= camera_data_in; // is this really necessary?
											half_pixel_ready <= 0;
											pixel_valid_out <= 1;
											pixel_data_out <= {last_sampled_data, camera_data_in};
										end 
									endcase
								end else if (camera_hs_in == 0) begin //row is done
									last_sampled_data <= 0;
									half_pixel_ready <= 0; // reset this
									pixel_hcount_out <= 0; // reset this
									pixel_valid_out <= 0; // no longer valid
									state <= HSYNC; // go to HSYNC state
								end 
							end 

							HSYNC: begin
								if (camera_hs_in == 1 && camera_vs_in == 1) begin // ready again to start displaying (does vs need to be taken into account?)
									state <= VALID;
									last_sampled_data <= camera_data_in;
									half_pixel_ready <= 1;
									pixel_vcount_out <= pixel_vcount_out + 1; // add 1 to our vertical count
								end else if (camera_vs_in == 0) begin // go to vsync since it just dropped
									state <= VSYNC;
								end 
							end

							VSYNC: begin
								if (camera_hs_in == 1 && camera_vs_in == 1)begin // start a new frame
									state <= VALID;
									pixel_vcount_out <= 0;
									last_sampled_data <= camera_data_in;
									half_pixel_ready <= 1;
								end 
							end 
							
						endcase

				 end else begin
					pixel_valid_out <= 0;

				 end 
				 
			end
	 end

endmodule

`default_nettype wire
