# Track D — RTL → GDS, driven by an LLM agent

**Team A71 · Longhorn Silicon · SSCS Chipathon 2026 (Track D — AI/LLM for circuits)**

Our Track-D thesis is not only *what* the chip does, but *how* it was built: an LLM
agent (Claude Code) drove the block from RTL to a signoff-clean, integration-ready
GDS — reading the repo, editing HDL and flow configs, running the physical-design
flow in a container, and **verifying its own output against the physical database**
rather than asserting success.

## What the agent did

| Step | Action | Evidence |
|---|---|---|
| Harden | Ran the LibreLane Classic flow (`librelane/coproc_core.yaml`) on GF180MCU to clean signoff. | run metrics; CI |
| Diagnose + fix the pin audit | Turned the status bus `obs_out[3:0]` into scalar ports `obs0..obs3` and the power pins `vdd/vss` into `VDD/VSS`, so the submitted GDS carries text labels that match `info.yaml` character-for-character. | commit `b4722ee` |
| Re-order for the slot | Moved `VSS` (chip-wide common ground) to pin 1 for the "BV" padframe slot. | commit `a432f94` |
| Verify + integrate | Re-hardened, scanned the hardened GDS to confirm the labels changed (`obs0..obs3`, `VDD/VSS`, no `obs_out[*]`), and reconciled the delivered padframe DEF (variants BV + BH) against our pin list. | commit `21819a4` |

## How it worked (methodology)

1. **Read before acting** — the agent inspected the RTL, the flow configs, and the
   failing audit to locate the true root cause (naming/labels, not logic).
2. **Edit HDL + flow config** — scalar ports in `src/lambda_kv_coproc.sv`, matching
   updates in `src/coproc_top.sv` / `src/tb_coproc_spi.sv`, and net names in the
   LibreLane configs and `info.yaml`.
3. **Run the real flow** — synthesis, place-and-route, and signoff in the LibreLane
   container against the GF180MCU PDK.
4. **Verify against the database** — a KLayout scan of the hardened GDS confirmed the
   text labels actually changed; signoff metrics were read from the run's
   `metrics.json`, not assumed.
5. **Commit with provenance** — every change is a small, described commit on `main`.

## Reproducibility

Every push runs the same two steps in CI (`.github/workflows/ci.yml`): the
self-checking SPI functional test (`make sim-coproc`) and the full hardening
(`make coproc`). The agent's work is therefore **auditable**, not asserted — anyone
can re-run it and reach the same signoff.

## Honest scope

Verification is at the **RTL + physical-signoff** level: functional RTL simulation
plus LVS (which ties the layout back to the synthesized netlist). Gate-level
simulation and exhaustive functional coverage are **named future work**, and nothing
here is silicon-proven — this is a pre-fabrication block for the shared reticle.
