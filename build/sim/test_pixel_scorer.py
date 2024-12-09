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


async def generate_clock(clock_wire):
    while True:  # repeat forever
        clock_wire.value = 0
        await Timer(5, units="ns")
        clock_wire.value = 1
        await Timer(5, units="ns")


@cocotb.test()
async def test_a(dut):
    """cocotb test for pixel_scorer receiver"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    dut._log.info("Holding reset...")
    dut.rst_in.value = 1

    await ClockCycles(dut.clk_in, 3)  # wait three clock cycles

    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0  # un reset device

    await ClockCycles(dut.clk_in, 3)

    for i in range(16):
        for j in range(16):
            dut.pixel_valid_in.value = 1
            dut.pixel_hcount_in.value = j
            dut.pixel_vcount_in.value = i
            dut.pixel_in.value = (j == 8) | (j == 7) and i == 2
            await ClockCycles(dut.clk_in, 1)

    dut.pixel_valid_in.value = 0
    await ClockCycles(dut.clk_in, 257)
    for i in range(16):
        for j in range(16):
            dut.pixel_valid_in.value = 0
            dut.hcount_in.value = j
            dut.vcount_in.value = i
            await ClockCycles(dut.clk_in, 1)


"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""


def pixel_scorer_runner():
    """Simulate the pixel_scorer using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / "pixel_scorer.sv",
        proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v",
    ]  # grow/modify this as needed.
    build_test_args = ["-Wall"]  # ,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {"HRES": 16, "VRES": 16}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="pixel_scorer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="pixel_scorer",
        test_module="test_pixel_scorer",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    pixel_scorer_runner()