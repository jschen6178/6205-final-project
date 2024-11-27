// highest score comes from a really low score relative to the max.


module scorer #( 
  parameter int MAX_PIXEL_SCORE = 7,
  parameter int HRES = 1280/4,
  parameter int VRES = 720/4
) ( 
  input wire clk_in,
  input wire rst_in,
  
  input wire is_last_pixel,
  input wire skeleton_bit,
  input wire [PWIDTH:0] pixel_score,
  input wire valid_in, // is this needed?

  output logic valid_out,
  output logic [2:0] final_score

);

localparam int HWIDTH = $clog2(HRES);
localparam int VWIDTH = $clog2(VRES);
localparam int PWIDTH = $clog2(MAX_PIXEL_SCORE);
localparam int LOG_MAX_SCORE = HWIDTH + VWIDTH + PWIDTH;

logic [LOG_MAX_SCORE-1:0] max_score;
logic [LOG_MAX_SCORE-1:0] skeleton_score;
// this is hardcoded. for loop could be better?
logic [LOG_MAX_SCORE-1:0] perfect_score;



always_comb begin
  perfect_score = max_score >> 3;

  final_score = (skeleton_score < perfect_score) ? 0 :
                (skeleton_score < perfect_score*2) ? 1 :
                (skeleton_score < perfect_score*3) ? 2 :
                (skeleton_score < perfect_score*4) ? 3 :
                (skeleton_score < perfect_score*5) ? 4 :
                (skeleton_score < perfect_score*6) ? 5 :
                (skeleton_score < perfect_score*7) ? 6 : 7;
end

always_ff @(posedge clk_in) begin
  if (rst_in) begin
    valid_out <= 0;
    max_score <= 0;
    skeleton_score <= 0;
  end
  if (is_last_pixel) begin
    valid_out <= 1;
  end else
    valid_out <= 0;
    max_score = max_score + MAX_PIXEL_SCORE;
    skeleton_score <= skeleton_bit ? skeleton_score + pixel_score : skeleton_score;
end
endmodule