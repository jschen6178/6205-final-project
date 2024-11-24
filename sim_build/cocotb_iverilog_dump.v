module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/jc/Documents/GitHub/6205-final-project/sim_build/binning_2.fst");
    $dumpvars(0, binning_2);
end
endmodule
