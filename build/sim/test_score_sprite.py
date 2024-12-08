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
    """cocotb test for score_sprite receiver"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())


    await ClockCycles(dut.clk_in, 3)

    for i in range(256):
        for j in range(256):
            dut.data_valid_in.value = 1
            dut.hcount_in.value = j
            dut.vcount_in.value = i
            dut.score.value = 0
            await ClockCycles(dut.clk_in, 1)
    await ClockCycles(dut.clk_in, 10)


"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""


def score_sprite_runner():
    """Simulate the score_sprite using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / "score_sprite.sv",
        proj_path / "hdl" / "block_sprite.sv",
    ]  # grow/modify this as needed.
    build_test_args = ["-Wall"]  # ,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="score_sprite",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="score_sprite",
        test_module="test_score_sprite",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    score_sprite_runner()
