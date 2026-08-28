# Verification & validation summary

**Team A71 · Longhorn Silicon · Lambda KV-Cache Coprocessor (KVE + TIU)**

## 1. Functional — self-checking SPI test

`src/tb_coproc_spi.sv` drives the block end-to-end over the 4-wire SPI link at the
workshop tile size (D=2, L=2) and checks deterministic outcomes:

| Check | Result |
|---|---|
| FSM completes — `STATUS.done` asserts, `STATUS.err` stays 0 | PASS |
| TIU eviction slot == argmin(mass) | PASS |
| TIU keep bitmap == (mass ≥ threshold) per slot | PASS |
| ACU precision gate == expected (never fires at L=2) | PASS |
| KVE codes within the INT3 range [-4, 3] | PASS |
| KVE scale readback stable across reads | PASS |

Run it: `make sim-coproc` → `COPROC SPI FUNCTIONAL TEST: ALL CHECKS PASS`.

## 2. Physical — signoff (all zero)

Hardened with `librelane/coproc_core.yaml` (LibreLane Classic, GF180MCU):

| Signoff check | Count |
|---|---|
| Magic DRC | 0 |
| KLayout DRC | 0 |
| Routing DRC | 0 |
| LVS errors (device/net/pin diffs) | 0 |
| Antenna (violating nets / pins) | 0 |
| XOR differences | 0 |
| Setup / hold violations | 0 |

| Metric | Value |
|---|---|
| Die area | 502.89 × 520.81 µm (0.262 mm²) |
| Std cells | 7,080 (~62 % utilization) |
| Clock | 300 ns period (closes the combinational CQ-3 value path) |
| PDK / SCL | gf180mcuD · `gf180mcu_fd_sc_mcu7t5v0` |

GDS text labels were confirmed post-harden (`obs0..obs3`, `VDD`, `VSS`, and the SPI
signals; no `obs_out[*]`), which is exactly what the padframe pin audit matches.

## 3. Reproducibility

CI (`.github/workflows/ci.yml`) re-runs `make sim-coproc` and `make coproc` on every
push, reproducing both the functional pass and the signoff on clean infrastructure.

## 4. Honest gaps (not claimed as done)

- **No gate-level simulation** of the coprocessor — the evidence chain is RTL sim +
  LVS, which is standard for this flow, but the post-layout netlist is not simulated.
- The SPI test is a **targeted deterministic self-check**, not exhaustive coverage.
  KVE bit-exactness vs. the behavioral reference is covered by block-level testbenches
  in the source monorepo, not re-run here.
- **Pad-level behavior** (the core driving the real pads — output-enable/tristate) is
  handled by the org's scripted padframe integration and is not self-verified here.
- Nothing is **silicon-proven**; this is a pre-fabrication block.
