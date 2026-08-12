# GF180MCU GDSII — Longhorn TIU

`chip_top.gds.gz` is the hardened GDSII for the Longhorn Token Importance Unit
(H2O heavy-hitter KV-cache eviction core) on GlobalFoundries **GF180MCU (180 nm)**,
produced by the LibreLane `Chip` flow in CI. Gunzip before use:

```bash
gunzip -k chip_top.gds.gz   # -> chip_top.gds (~57 MB)
```

| Property | Value |
|---|---|
| PDK / node | gf180mcuD, 180 nm (5 V, `gf180mcu_fd_sc_mcu7t5v0`) |
| Slot | `0p5x0p5` — die 1936 × 2531 µm, core 1052 × 1647 µm |
| Top cell | `chip_top` (padring) wrapping `chip_core` → `token_importance_unit` (N_SLOTS = 4) |
| Clock | 25 MHz |
| Power | 2.60 mW |
| Timing | hold clean; nominal `tt_025C_5v00` corner clean |
| Verification | cocotb pad-level sim + gate-level sim pass in CI |

Provenance: built from commit history on `master`; regenerated on every push by
`.github/workflows/ci.yml` (`make sim` → `make librelane-condensed` → `make sim-gl`).
Layout render: [`../docs/chip_top_layout.png`](../docs/chip_top_layout.png).

Known tail: the slow corner `ss_125C_4v50` reports non-fatal setup/slew/cap
warnings (GF180 slow-corner library/IO floor, precheck-passing) — see the note in
`librelane/config.yaml`.
