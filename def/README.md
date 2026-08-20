# def/ — org-provided padframe DEF

The Chipathon integration team generates the padframe DEF from our `info.yaml`
pin list + core area and delivers it here (per integration lead, ETA week of
2026-08-20; the trial run uses the DEF-integrated GDS).

**DEF-day:**
1. Save the delivered DEF here, e.g. `def/PADFRAME_TEMPLATE.def`.
2. Point `librelane/coproc_integrated.yaml` → `FP_DEF_TEMPLATE` at it.
3. Verify the DEF pin names match `src/coproc_top.sv` ports
   (`clk, rst_n, spi_sclk, spi_cs_n, spi_mosi, spi_miso, obs0..obs3, vdd, vss`).
4. Harden: `make coproc-integrated`.

See `docs/INTEGRATION.md` for the full procedure.
