# Shared-reticle integration — DEF-day procedure

The Chipathon integration flow (per integration lead): we submit a **core-only**
block + `info.yaml` pin list; the org generates the padframe and returns a **DEF**
sized to our area + pins; we harden our core **into** that DEF. The trial run / DRC
dry-run uses the DEF-integrated GDS (not the standalone core).

## What's already in place
- `info.yaml` — pin allocation (accepted by the integration lead).
- `gds/lambda_kv_coproc.gds` — standalone core, DRC/LVS/antenna/STA-clean (0.262 mm²).
- `src/coproc_top.sv` — integration top; **scalar** ports named to match `info.yaml`.
- `librelane/coproc_integrated.yaml` — harden config using `FP_DEF_TEMPLATE`.

## DEF-day steps
1. **Drop the DEF** the org delivers into `def/` (e.g. `def/PADFRAME_TEMPLATE.def`).
2. **Point the config at it** — set `FP_DEF_TEMPLATE` in
   `librelane/coproc_integrated.yaml` to that path.
3. **Reconcile names against the DEF** (the only real unknowns until we see it):
   - Pin names: `coproc_top.sv` ports must match the DEF pins exactly
     (`clk, rst_n, spi_sclk, spi_cs_n, spi_mosi, spi_miso, obs0..obs3, vdd, vss`).
     If the DEF uses a bus (`obs_out[3:0]`) or `VDD/VSS`, edit the ports in
     `coproc_top.sv` and the `VDD_NETS/GND_NETS` in the config.
   - PDN: if the padframe DEF already carries power rings/straps, keep our PDN
     minimal; otherwise add a `PDN_CFG`.
4. **Harden:** `make coproc-integrated` → `final_integrated/gds/coproc_top.gds`.
5. **Signoff:** confirm DRC / LVS / antenna / STA clean; update `lvs_config.json`
   `TOP_SOURCE` to `coproc_top` and the submission GDS path.
6. **Submit** the integrated GDS for the trial run.

## Notes
- Functional proof of the core is unchanged: `make sim-coproc` (SPI test).
- `chip_id`/logo tiles: whether they live in the org padframe or are ours to add
  is a DEF-day question — confirm with the integration lead once the DEF is in hand.
