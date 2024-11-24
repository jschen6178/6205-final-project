module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/jc/Documents/6205-digital-systems-lab/lab05/sim/sim_build/center_of_mass.fst");
    $dumpvars(0, center_of_mass);
end
endmodule
