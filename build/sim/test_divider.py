import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.triggers import Timer, ClockCycles, FallingEdge, ReadOnly, RisingEdge
from cocotb.clock import Clock
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


@cocotb.test()
async def test_a(dut):
    """cocotb test for center_of_mass receiver"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    dut._log.info("Holding reset...")
    dut.rst_in.value = 1

    await ClockCycles(dut.clk_in, 3)  # wait three clock cycles

    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0  # un reset device
    await ClockCycles(dut.clk_in, 3)  # wait a few clock cycles

    dut.dividend_in.value = 1990000
    dut.divisor_in.value = 20000
    dut.data_valid_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.data_valid_in.value = 0
    await RisingEdge(dut.data_valid_out)
    await FallingEdge(dut.clk_in)
    assert dut.quotient_out.value == 1990000 // 20000, "Quotient is not correct"
    assert dut.remainder_out.value == 1990000 % 20000, "Remainder is not correct"


"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""


def center_of_mass_runner():
    """Simulate the center_of_mass using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "divider.sv"]  # grow/modify this as needed.
    build_test_args = ["-Wall"]  # ,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {"WIDTH": 26}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="divider",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="divider",
        test_module="test_divider",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    center_of_mass_runner()

