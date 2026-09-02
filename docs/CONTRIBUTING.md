# Contributing — Lambda KV-Cache Coprocessor

**Team A71 · Longhorn Silicon · SSCS Chipathon 2026 · Track D (AI/LLM for circuits)**

Welcome, @sh9r. This is a **GF180MCU core-only KVE+TIU coprocessor** submitted to the
Chipathon shared reticle. The org pulls the final GDS straight from this repo's default
branch, so the golden rule is: **keep the default branch green and never break the
signoff GDS or `info.yaml` before the Sept 7 deadline** (see `docs/SUBMISSION.md`).

---

## Quick start / environment

Two things you can do locally; know which one needs the PDK.

**1. Functional SPI test — fast, no PDK, no docker.** Uses Icarus Verilog only:

```bash
make sim-coproc      # builds src/tb_coproc_spi.sv with iverilog, expects "ALL CHECKS PASS"
```

This is the first thing to run — it is the functional proof of the block and CI gates
on it. If `iverilog` isn't on your path, get it from your package manager or the nix
shell below.

**2. Harden the core (RTL -> GDS).** `make coproc` runs LibreLane and *normally* needs
`ciel` + the gf180mcuD PDK cloned locally (`make clone-pdk`). **In this environment the
harden is run via the LibreLane docker image instead** — see the header of
`librelane/coproc_core.yaml` for the exact command:

```bash
docker run --rm -e HOME=/tmp --user "$(id -u):$(id -g)" \
  -v <repo>:/work -w /work ghcr.io/librelane/librelane:3.0.5 \
  librelane librelane/coproc_core.yaml --pdk gf180mcuD \
    --pdk-root /work/gf180mcu --manual-pdk --save-views-to /work/final_core
```

**Nix option (from the README):** `nix-shell` (or `nix develop`) gives you the full
toolchain — LibreLane, iverilog, verilator, cocotb, gtkwave — pinned by `flake.nix`.
CI itself builds this way. Use it if you want `make coproc` / `make sim` without docker.

Outputs: hardened views land in `final_core/`; the submission GDS is
`gds/lambda_kv_coproc.gds` (502.89 × 520.81 µm, 0.262 mm², signoff-clean).

---

## Repo map

| Path | What lives there |
|---|---|
| `src/` | SystemVerilog RTL — coproc top + FSM, SPI loader, KVE/TIU/ACU blocks, and the `tb_coproc_spi.sv` self-check. |
| `librelane/` | Hardening configs — `coproc_core.yaml` (active core-only harden), `coproc_integrated.yaml` (harden into the org DEF), plus the legacy padring `config.yaml`. |
| `def/` | Org-delivered padframe DEFs (`A71_BV`, `A71_BH`) + pad maps / interface YAMLs. Input to the integrated harden. |
| `gds/` | The signoff-clean core GDS pulled for submission (`lambda_kv_coproc.gds`). |
| `docs/` | `INTEGRATION.md`, `VERIFICATION.md`, `SUBMISSION.md`, `LLM_APPROACH.md`; `docs/spec/` (SPI programming + micro-arch spec) and `docs/paper/` (IEEE-style writeup). Start with `docs/spec/`. |
| `cocotb/` | Python testbench for the *old* padring `chip_top` flow (`chip_top_tb.py`), superseded by the core-only submission. |

---

## How the block works

The host streams everything over a **4-wire SPI slave** (mode 0, MSB-first); the
`spi_loader.sv` front end turns SPI bytes into a byte-addressed bus, and an FSM in
`lambda_kv_coproc.sv` runs one "compress step":

- **KVE** (`cq_value_path_wht_syn.sv` + `wht_unit_syn.sv`/`cq_units_syn.sv`) forward-WHT
  rotates each value token and quantizes to INT3 codes + one fp16 scale (bit-exact CQ-3).
- **TIU** (`token_importance_unit.sv`) does H2O heavy-hitter scoring over the cache slots
  -> per-slot keep-tier bitmap + one eviction victim slot (argmin of mass).
- **ACU** (`precision_controller.sv`) is a divide-free precision gate that decides whether
  a tile stays fp16.

The host writes values (V) + attention masses (W), pulses START, polls STATUS, then reads
back codes/scale + the decision byte. See `docs/spec/lambda_kv_coproc_spec.pdf` for the
address map, byte protocol, and FSM detail. Default sizing here is D=2, L=2 (workshop tile).

---

## Good ways to contribute

Prioritized, each tied to a real gap in the repo. Pick from the top.

1. **Pad-adapter wrapper for the self-hosted integrated harden** *(touches
   `src/coproc_top.sv`, drives `make coproc-integrated` / `librelane/coproc_integrated.yaml`).*
   The delivered DEF (`def/A71_BV/A71_BV.def`) exposes the gf180 pad **core-side**
   interface — 67 pins (`_IN/_OUT/_OE/_IE/_CS/_SL/_PU/_PD/_PDRV0/_PDRV1` per bidir pad,
   `<name>+_PU/_PD` per input), *not* the scalar ports `coproc_top` has today. A wrapper
   that drives `<pin>_OUT` from our scalar outputs, sets `_OE=1` (gate MISO on `spi_cs_n`),
   ties `_IN` off, and constants the config bits would let the integrated harden route
   cleanly. This is the biggest open item; steps are in `docs/INTEGRATION.md` §3. Optional
   for submission (the org scripts the pad wiring), but the highest-value engineering task.

2. **Gate-level (post-layout) simulation** *(new testbench; wire into `Makefile`/CI).*
   `docs/VERIFICATION.md` §4 explicitly lists this as **not done** — evidence today is RTL
   sim + LVS, but the post-layout netlist is never simulated. Add a GL sim of the hardened
   `lambda_kv_coproc` netlist re-running the SPI functional checks.

3. **Broaden the SPI functional test** *(touches `src/tb_coproc_spi.sv`).* It currently
   covers a single deterministic D=2/L=2 case (`docs/VERIFICATION.md` §1, §4 calls it a
   "targeted deterministic self-check"). Add more vectors — different mass patterns so
   eviction/keep-tier and the ACU gate exercise non-trivial outcomes, larger D/L, edge
   cases in KVE code range.

4. **Metal2 corner keep-out verification** *(check against
   `def/A71_BV/A71_BV_interface.yaml`).* The integrator (kano bailey) marks a
   `metal2_blockages` corner region in the delivered interface YAML. Add a check that our
   hardened layout stays clear of that keep-out (and the routing-blockage layers) so the
   integrated harden and the org's scripted merge don't collide with the padframe.

Only take on tasks you can ground in the repo like the above — if a fix touches the GDS or
`info.yaml`, flag it, because those are the frozen submission artifacts.

---

## Workflow

- **Branch** off the default branch; never commit signoff-breaking changes directly to it.
- **Small, described commits** — one logical change each, with a message that says why.
- **Push over HTTPS only.** The remote is
  `https://github.com/LonghornSilicon/gf180-longhorn-tiu.git`; SSH pushes are rejected.
- **CI runs on every push** (`.github/workflows/ci.yml`): it clones the PDK, runs
  `make sim-coproc` (SPI functional test) and `make coproc` (harden the core), and uploads
  the GDS + render. Both must stay green — a red default branch risks the submission that
  gets pulled from it.
- Open a PR for review; keep `info.yaml` and `gds/lambda_kv_coproc.gds` untouched unless
  the change is deliberately a signoff update coordinated with the team.
