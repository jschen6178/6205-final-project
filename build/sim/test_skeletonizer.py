import random
import cocotb
import os
import sys
import numpy as np
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


def solve_skeleton(image):
    def calculate_A(p):
        count = 0
        for k in range(len(p)):
            if p[k] == 0 and p[(k + 1) % len(p)] == 1:
                count += 1
        return count

    dx = np.array([0, -1, -1, 0, 1, 1, 1, 0, -1])
    dy = np.array([0, 0, 1, 1, 1, 0, -1, -1, -1])

    NUM_ITERS = 100
    for _ in range(NUM_ITERS):
        print(f"Iteration {_}")
        count = 0
        new_image = image.copy()
        for i in range(1, image.shape[0] - 1):
            for j in range(1, image.shape[1] - 1):
                p = image[i + dx, j + dy]

                B_p = np.sum(p[1:])  # neighbors of p1
                A_p = calculate_A(p[1:])
                p246 = p[1] * p[3] * p[5]  # p2 * p4 * p6
                p468 = p[3] * p[5] * p[7]  # p4 * p6 * p8

                if (
                    2 <= B_p <= 6
                    and A_p == 1
                    and p246 == 0
                    and p468 == 0
                    and image[i, j] == 1
                ):
                    new_image[i, j] = 0
                    count += 1
        for i in range(image.shape[0]):
            new_image[i, 0] = 0
            new_image[i, image.shape[1] - 1] = 0
        for j in range(image.shape[1]):
            new_image[0, j] = 0
            new_image[image.shape[0] - 1, j] = 0

        image = new_image.copy()
        if count == 0:
            break
        count = 0
        for i in range(1, image.shape[0] - 1):
            for j in range(1, image.shape[1] - 1):
                p = image[i + dx, j + dy]

                B_p = np.sum(p[1:])  # neighbors of p1
                A_p = calculate_A(p[1:])
                p248 = p[1] * p[3] * p[7]  # p2 * p4 * p8
                p268 = p[1] * p[5] * p[7]  # p2 * p6 * p8

                if (
                    2 <= B_p <= 6
                    and A_p == 1
                    and p248 == 0
                    and p268 == 0
                    and image[i, j] == 1
                ):
                    new_image[i, j] = 0
                    count += 1
        image = new_image
        if count == 0:
            break
    return image


# image_str = """
# 0000000000000000
# 0000000000000000
# 0000111111100000
# 0001111111110000
# 0011111001111000
# 0011110000111000
# 0011110000111000
# 0011110000111000
# 0011110000111000
# 0011110000111000
# 0011110000111000
# 0011110000111000
# 0001110000000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
# """
# image = [[int(c) for c in line] for line in image_str.strip().split("\n")]
data = [[random.randint(0, 1) for _ in range(8)] for _ in range(8)]
image = np.array(data)
print("\n".join(["".join([str(cell) for cell in row]) for row in image]))
answer = solve_skeleton(image)
print("\n".join(["".join([str(cell) for cell in row]) for row in answer]))


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
    for i in range(8):
        for j in range(8):
            dut.hcount_in.value = j
            dut.vcount_in.value = i
            dut.pixel_in.value = int(image[i][j])
            dut.pixel_valid_in.value = 1
            await ClockCycles(dut.clk_in, 1)
        dut.pixel_valid_in.value = 0
        await ClockCycles(dut.clk_in, 2)
    await First(RisingEdge(dut.pixel_valid_out), ClockCycles(dut.clk_in, 200000))
    await FallingEdge(dut.clk_in)
    output = np.zeros((8, 8), dtype=int)
    for i in range(8):
        for j in range(8):
            # print(f"i: {i}, j: {j}")
            assert dut.hcount_out.value == j
            assert dut.vcount_out.value == i
            # assert dut.skeleton_out.value == int(answer[i][j])
            output[i][j] = dut.skeleton_out.value
            await FallingEdge(dut.clk_in)
    await ClockCycles(dut.clk_in, 10)
    assert dut.busy.value == 0
    print("\n".join(["".join([str(cell) for cell in row]) for row in output]))
    assert np.array_equal(output, answer)


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
    parameters = {"HORIZONTAL_COUNT": 8, "VERTICAL_COUNT": 8}
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
