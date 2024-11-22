module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic option;
  logic add_bit;
  logic [7:0] data_byte1;
  logic [7:0] data_byte2;
  logic [3:0] one_count;

  //your code here, friend

  always_comb begin
    one_count = 3'b0;
    data_byte1 = data_in;
    data_byte2 = data_in;
    for (int i = 0; i < 8; i = i + 1) begin
      one_count = one_count + data_in[i];
    end

    option = (one_count > 4) || (one_count == 4 && data_in[0] == 0);
    
    case(option)
      0: begin // option 1
        qm_out[0] = data_byte2[0];
        for (int i = 1; i < 8; i = i + 1) begin
          qm_out[i] = qm_out[i-1] ^ data_in[i];
        end
        qm_out[8] = 1;
      end

      1: begin // option 2
        qm_out[0] = data_byte2[0];
        for (int i = 1; i < 8; i = i + 1) begin
          qm_out[i] = ~(qm_out[i-1] ^ data_in[i]);
        end
        qm_out[8] = 0;
      end 

    endcase
  end 


endmodule //end tm_choice
