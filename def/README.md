# def/ — org-provided padframe DEF (DELIVERED 2026-08-26)

The Chipathon integration team generated the A71 padframe from our `info.yaml`
pin list + core area and delivered it here. We are selected for **two** 1/8-slot
variants (`def/A71_selected_variants.json`): **BV** (vertical, 550 × 1110 µm) and
**BH** (horizontal, 1110 × 550 µm). Either can hold our core (502.89 × 520.81 µm).

```
def/
  A71_selected_variants.json     # which variants + the GDS text labels the org ingested
  A71_BV/                        # vertical 1/8 slot (primary)
    A71_BV.def                   # slot template: die area + core-side pad pins  <- FP_DEF_TEMPLATE
    A71_BV_pad_map.yaml          # user pin -> physical pad slot / cell
    A71_BV_interface.yaml        # per-pin core-side terminals (IN/OUT/OE/IE/CS/SL/PU/PD/PDRV)
    A71_BV_padring.{v,def,cfg,svg}  # the full pad ring (pads only; does not include our block)
  A71_BH/                        # horizontal 1/8 slot (alternate) — same files
```

**Confirmed against our submission (both variants):** pin names, io_types, and
order all match `info.yaml` exactly — `VSS` = pin 1 (slot W12, ground), then
`clk, rst_n, spi_sclk, spi_cs_n, spi_mosi, spi_miso, obs0..obs3`, `VDD` = pin 12
(slot N01, power). The 4 unused slots (N02–N05) were auto-filled by the org with
analog pads. The org ingested our **fixed** GDS (labels `obs0..obs3` + `VDD/VSS`,
no `obs_out`).

**Pad interface:** `A71_*.def` exposes the gf180 pad **core-side** terminals, not
scalars — each bidir pad (`spi_miso`, `obs0..obs3`) presents 10 signals
(`_IN/_OUT/_OE/_IE/_CS/_SL/_PU/_PD/_PDRV0/_PDRV1`) and each input pad presents
`<name>` + `<name>_PU/_PD` (67 pins total). The org's scripted integration wires
our scalar-labeled core into these pads on their side.

**Self-run trial harden (optional):** to harden `coproc_top` into this DEF
ourselves, a pad-adapter wrapper exposing/driving all 67 pad ports is required
first (drive `_OE`, tie off `_IN`, set config bits). Then point
`librelane/coproc_integrated.yaml` `FP_DEF_TEMPLATE` at the variant DEF and run
`make coproc-integrated`. See `docs/INTEGRATION.md`.
