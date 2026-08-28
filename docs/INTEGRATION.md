# Shared-reticle integration — DEF-day procedure

The Chipathon integration flow (per integration lead): we submit a **core-only**
block + `info.yaml` pin list; the org generates the padframe and returns a **DEF**
sized to our area + pins; we harden our core **into** that DEF. The trial run / DRC
dry-run uses the DEF-integrated GDS (not the standalone core).

## Status (2026-08-26): DEF DELIVERED
The org delivered the padframe DEF — variants **BV** + **BH**, archived under
`def/` (see `def/README.md`). Pin names, io_types, and order were reconciled and
**match `info.yaml` exactly** (`VSS`=pin 1 … `VDD`=pin 12), power nets confirmed
`VDD`/`VSS`. The standalone core submission is complete and consistent with the
DEF; the org's scripted flow wires our scalar-labeled core GDS into the pads.
A self-run integrated harden additionally needs a pad-adapter wrapper (see step 3).

## What's already in place
- `info.yaml` — pin allocation (accepted by the integration lead).
- `gds/lambda_kv_coproc.gds` — standalone core, DRC/LVS/antenna/STA-clean (0.262 mm²).
- `src/coproc_top.sv` — integration top; **scalar** ports named to match `info.yaml`.
- `librelane/coproc_integrated.yaml` — harden config using `FP_DEF_TEMPLATE`.

## DEF-day steps
1. **Drop the DEF** the org delivers into `def/` (e.g. `def/PADFRAME_TEMPLATE.def`).
2. **Point the config at it** — set `FP_DEF_TEMPLATE` in
   `librelane/coproc_integrated.yaml` to that path.
3. **Reconcile names against the DEF** — DONE for the delivered DEF:
   - User pins match `info.yaml`/`coproc_top.sv` scalar names exactly
     (`clk, rst_n, spi_sclk, spi_cs_n, spi_mosi, spi_miso, obs0..obs3, VDD, VSS`).
     The earlier `obs_out[3:0]` / lowercase `vdd,vss` risks are resolved.
   - BUT the DEF pins are the gf180 pad **core-side** interface (67 pins), not the
     scalars: bidir pads (`spi_miso, obs0..obs3`) expose
     `_IN/_OUT/_OE/_IE/_CS/_SL/_PU/_PD/_PDRV0/_PDRV1`; input pads expose
     `<name>` + `<name>_PU/_PD`. A **pad-adapter wrapper** is required to run a
     self-hosted integrated harden: drive `<pin>_OUT` from our scalar output,
     `<pin>_OE=1` (outputs) / gate MISO on `spi_cs_n`, tie `<pin>_IN` off, and set
     the config bits (`_IE,_CS,_SL,_PU,_PD,_PDRV*`) to constants. This is optional —
     the org scripts the pad wiring from our scalar-labeled core GDS.
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
