# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import random
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Edge, RisingEdge, FallingEdge, ClockCycles
from cocotb_tools.runner import get_runner

sim = os.getenv("SIM", "icarus")
gl = os.getenv("GL", False)
pdk_root = os.getenv("PDK_ROOT", Path(__file__).resolve().parent / "../gf180mcu")
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_fd_sc_mcu7t5v0")
pad = os.getenv("PAD", "gf180mcu_fd_io")
sram = os.getenv("SRAM", "gf180mcu_fd_ip_sram")
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "chip_top"

async def set_defaults(dut):
    dut.input_PAD.value = 0

async def enable_power(dut):
    dut.VDD.value = 1
    dut.VSS.value = 0

async def start_clock(clock, freq=50):
    """Start the clock @ freq MHz"""
    c = Clock(clock, 1 / freq * 1000, "ns")
    cocotb.start_soon(c.start())


async def reset(reset, active_low=True, time_ns=1000):
    """Reset dut"""
    cocotb.log.info("Reset asserted...")

    reset.value = not active_low
    await Timer(time_ns, "ns")
    reset.value = active_low

    cocotb.log.info("Reset deasserted.")


async def start_up(dut):
    """Startup sequence"""
    await set_defaults(dut)
    if gl:
        await enable_power(dut)
    await start_clock(dut.clk_PAD)
    await reset(dut.rst_n_PAD)


@cocotb.test()
async def test_tiu(dut):
    """Longhorn TIU eviction smoke test through the slot pads.

    Drives op/slot on input_PAD (bits [1:0]=op, [3:2]=slot); reads the result off
    bidir_PAD ([10]=evict_valid, [9:8]=evict_slot). Weight-free case: LOAD all four
    slots (scores stay 0), then EVICT -> the argmin of equal scores is the lowest
    index, slot 0. The weighted cases are covered by the RTL sim + gate-level test.
    """
    logger = logging.getLogger("tiu_tb")
    await start_up(dut)                       # input_PAD=0, clock, reset
    nb = len(dut.bidir_PAD)

    async def do_op(op, slot=0):
        # Drive inputs on the falling edge so they are stable before the next
        # rising edge samples them (driving at the rising edge races the sample
        # and can drop the very first op).
        await FallingEdge(dut.clk_PAD)
        dut.input_PAD.value = ((slot & 0x3) << 2) | (op & 0x3)   # 1=ACC 2=LOAD 3=EVICT
        await RisingEdge(dut.clk_PAD)

    def obit(s, i):                            # bit i (from LSB) of the MSB-first string
        return s[nb - 1 - i]

    # install four fresh tokens (score := 0)
    for s in range(4):
        await do_op(2, s)                      # LOAD slot s

    # evict: all four scores equal 0 -> the serialized argmin seeds on slot 0 and
    # keeps it under a strict less-than, so the lowest index wins -> slot 0.
    await do_op(3)                             # EVICT (pulse evict_req for one cycle)
    await FallingEdge(dut.clk_PAD)
    dut.input_PAD.value = 0                     # back to NOP before the FSM returns to IDLE

    victim = None
    for _ in range(12):
        await ClockCycles(dut.clk_PAD, 1)
        s = str(dut.bidir_PAD.value)
        if obit(s, 10) == "1":                 # evict_valid
            victim = int(obit(s, 9) + obit(s, 8), 2)   # evict_slot[1:0]
            break

    assert victim == 0, f"expected victim slot 0, got {victim}"
    logger.info(f"TIU eviction OK through pads: victim = slot {victim}")


def chip_top_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [proj_path / "../src/"]

    # Set the LibreLane PDK/SCL/PAD defines
    defines[f"PDK_{pdk.replace('-','_')}"] = True
    defines[f"SCL_{scl}"] = True
    defines[f"PAD_{pad}"] = True
    defines[f"SRAM_{sram}"] = True

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        if scl != "gf180mcu_as_sc_mcu7t3v3":
            sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/{hdl_toplevel}.pnl.v")

        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
        sources.append(proj_path / "../src/chip_top.sv")
        sources.append(proj_path / "../src/chip_core.sv")
        sources.append(proj_path / "../src/token_importance_unit.sv")

    sources += [
        # IO pad models
        Path(pdk_root) / pdk / f"libs.ref/{pad}/verilog/{pad}.v",
        
        # SRAM macros
        Path(pdk_root) / pdk / f"libs.ref/{sram}/verilog/{sram}__sram512x8m8wm1.v",
        
        # Custom IP
        proj_path / "../ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",
        proj_path / "../ip/gf180mcu_ws_ip__marker/vh/gf180mcu_ws_ip__marker.v",
        proj_path / "../ip/gf180mcu_ws_ip__qrcode_id/vh/gf180mcu_ws_ip__qrcode_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__shuttle_id/vh/gf180mcu_ws_ip__shuttle_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__project_id/vh/gf180mcu_ws_ip__project_id.v",
        
    ]

    build_args = []

    if sim == "icarus":
        # For debugging
        # build_args = ["-Winfloop", "-pfileline=1"]
        pass

    if sim == "verilator":
        build_args = ["--timing", "--trace", "--trace-fst", "--trace-structs"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        always=True,
        includes=includes,
        build_args=build_args,
        waves=True,
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="chip_top_tb,",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    chip_top_runner()
