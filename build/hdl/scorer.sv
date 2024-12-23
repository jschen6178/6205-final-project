// highest score comes from a really low score relative to the max.
// changed form 63 to 31 make sure bit widths are okay

module scorer #(
    parameter int MAX_PIXEL_DISTANCE = 31,
    parameter int MAX_PIXEL_SCORE = 7,
    parameter int HRES = 320,
    parameter int VRES = 180
) (
    input wire clk_in,
    input wire rst_in,
    input wire [HWIDTH-1:0] hcount_in,
    input wire [VWIDTH-1:0] vcount_in,
    input wire skeleton_bit,  //tells you if this is part of the human skeleton or not
    input wire [DWIDTH-1:0] pixel_distance,  //distance of the pixel to the model skeleton
    input wire valid_in,  // is this needed?

    output logic valid_out,
    output logic [2:0] final_score
);

  localparam int HWIDTH = $clog2(HRES);
  localparam int VWIDTH = $clog2(VRES);
  localparam int INF = HRES + VRES;  // Larger than the largest possible distance
  localparam int DWIDTH = $clog2(INF + 1);
  localparam int MWIDTH = $clog2(MAX_PIXEL_DISTANCE);
  localparam int PWIDTH = $clog2(MAX_PIXEL_SCORE);
  localparam int LOG_MAX_SCORE = HWIDTH + VWIDTH + PWIDTH;

  logic [MWIDTH-1:0] cutoff_pixel_distance;
  logic [MWIDTH-3:0] pixel_score;
  logic [LOG_MAX_SCORE-1:0] max_score;
  logic [LOG_MAX_SCORE-1:0] skeleton_score;
  // this is hardcoded. for loop could be better?
  logic [LOG_MAX_SCORE-1:0] perfect_score;

  always_comb begin
    cutoff_pixel_distance = (pixel_distance > MAX_PIXEL_DISTANCE) ? MAX_PIXEL_DISTANCE : pixel_distance;

    pixel_score = cutoff_pixel_distance >> 2;

    perfect_score = max_score >> 3;

    final_score = (skeleton_score < perfect_score) ? 0 :
                (skeleton_score < perfect_score*2) ? 1 :
                (skeleton_score < perfect_score*3) ? 2 :
                (skeleton_score < perfect_score*4) ? 3 :
                (skeleton_score < perfect_score*5) ? 4 :
                (skeleton_score < perfect_score*6) ? 5 :
                (skeleton_score < perfect_score*7) ? 6 : 7;
  end

  typedef enum {
    IDLE,
    SCORING,
    OUTPUT
  } score_state;

  score_state state;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      valid_out <= 0;
      max_score <= 0;
      skeleton_score <= 0;
    end else begin
      case (state)
        IDLE: begin
          valid_out <= 0;
          max_score <= 0;
          skeleton_score <= 0;
          if (valid_in && vcount_in == 0) state <= SCORING;
        end
        SCORING: begin
          if (hcount_in == HRES - 1 && vcount_in == VRES - 1) begin
            state <= OUTPUT;
          end
          if (skeleton_bit) begin
            max_score <= max_score + MAX_PIXEL_SCORE;
            skeleton_score <= skeleton_score + pixel_score;
          end
        end
        OUTPUT: begin
          valid_out <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
