# GF180MCU GDSII — Lambda KV-Cache Coprocessor (KVE + TIU)

`lambda_kv_coproc.gds` is the hardened, **core-only** GDSII for the Lambda KV-cache
coprocessor (KVE value compression + TIU token-importance/eviction + precision gate)
on GlobalFoundries **GF180MCU (180 nm)**, produced by the LibreLane `Classic` flow
(`librelane/coproc_core.yaml`). This is the **pre-integration** block — no pads, no
padring; the Chipathon integration team generates the padframe from `info.yaml` and
returns a DEF to harden this core into.

| Property | Value |
|---|---|
| PDK / node | gf180mcuD, 180 nm (5 V, `gf180mcu_fd_sc_mcu7t5v0`) |
| Top cell | `lambda_kv_coproc` (core-only, no padring) |
| Die area | 502.89 × 520.81 µm (0.262 mm²) |
| Std cells | 7,080 (~62% util) |
| Clock | 300 ns period; setup +93 ns / hold +0.77 ns (clean) |
| Signoff | Magic DRC, KLayout DRC, routing DRC, LVS, antenna, XOR — all 0 |
| Host interface | 4-wire SPI slave (see `info.yaml`) |

Verification: self-checking SPI functional test (`src/tb_coproc_spi.sv`) — all checks
pass; cross-block RTL cosim on real Qwen vectors — all blocks pass.
