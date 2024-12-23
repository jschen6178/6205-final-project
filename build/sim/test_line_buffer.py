import cocotb
import libscrc
import struct
import random
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import (
    ClockCycles,
    FallingEdge,
    RisingEdge,
)
from cocotb.runner import get_runner


MODULE_NAME = "line_buffer"


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
        for i in range(5):
            for j in range(8):
                dut.hcount_in.value = j
                dut.vcount_in.value = i
                dut.pixel_data_in.value = i * 8 + j
                dut.data_valid_in.value = 1
                await ClockCycles(dut.clk_in, 1)
            dut.data_valid_in.value = 0
            await ClockCycles(dut.clk_in, 2)


def main():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / f"{MODULE_NAME}.sv",
        proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v",
    ]
    build_test_args = ["-Wall"]
    parameters = {"HRES": 8, "VRES": 5}
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
