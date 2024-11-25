import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import (
    ClockCycles,
    FallingEdge,
    First,
    RisingEdge,
)
from cocotb.runner import get_runner


MODULE_NAME = "skeletonizer"


image_str = """
0000000000000000
0000000000000000
0000111111100000
0001111111110000
0011111001111000
0011110000111000
0011110000111000
0011110000111000
0011110000111000
0011110000111000
0011110000111000
0011110000111000
0001110000000000
0000000000000000
0000000000000000
0000000000000000
"""
image = [[int(c) for c in line] for line in image_str.strip().split("\n")]


@cocotb.test
async def test_a(dut):
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 3)  # wait three clock cycles
    await FallingEdge(dut.clk_in)
    dut._log.info("Releasing reset...")
    dut.rst_in.value = 0  # un reset device
    await ClockCycles(dut.clk_in, 2)
    for _ in range(3):
        for i in range(16):
            for j in range(16):
                dut.hcount_in.value = j
                dut.vcount_in.value = i
                dut.pixel_in.value = image[i][j]
                dut.pixel_valid_in.value = 1
                await ClockCycles(dut.clk_in, 1)
            dut.pixel_valid_in.value = 0
            await ClockCycles(dut.clk_in, 2)
        await First(FallingEdge(dut.busy), ClockCycles(dut.clk_in, 5000))


def main():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / f"{MODULE_NAME}.sv",
        proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v",
        proj_path / "hdl" / "line_buffer.sv",
    ]
    build_test_args = ["-Wall"]
    parameters = {"HORIZONTAL_COUNT": 16, "VERTICAL_COUNT": 16}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=MODULE_NAME,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=MODULE_NAME,
        test_module=__file__[__file__.rfind("/") + 1 : __file__.rfind(".py")],
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
