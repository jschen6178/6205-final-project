import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.triggers import Timer, ClockCycles, FallingEdge, ReadOnly
from cocotb.clock import Clock
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

half_pixels = [0x12, 0x34, 0x45, 0x56, 0x78, 0x12, 0x34, 0x45, 0x56, 0x78, 0x01, 0x22]
async def generate_clock(clock_wire):
	while True: # repeat forever
		clock_wire.value = 0
		await Timer(5,units="ns")
		clock_wire.value = 1
		await Timer(5,units="ns")
 
@cocotb.test()
async def test_a(dut):
    """cocotb test for center_of_mass receiver"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    
    dut._log.info("Holding reset...")
    dut.rst_in.value = 1
    
    await ClockCycles(dut.clk_in, 3) #wait three clock cycles
    
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0 #un reset device
    await ClockCycles(dut.clk_in, 3) #wait a few clock cycles
    

    for i in range(700):
        for j in range(700):
          dut.x_in.value = i
          dut.y_in.value = j
          dut.valid_in.value = 1
          await ClockCycles(dut.clk_in, 1)
    
    dut.valid_in.value = 0
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in, 3000)

    for i in range(700):
        for j in range(700):
          if (i == 450 and j == 350):
            dut.valid_in.value = 1
            dut.x_in.value = 450
            dut.y_in.value = 350
          else:
              dut.valid_in.value = 0
          await ClockCycles(dut.clk_in, 1)

    dut.valid_in.value = 0
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in, 3000)
    

            
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def center_of_mass_runner():
    """Simulate the center_of_mass using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "center_of_mass.sv", proj_path / "hdl" / "divider.sv"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="center_of_mass",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="center_of_mass",
        test_module="test_center_of_mass",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    center_of_mass_runner()
    