# Micro-architecture & programming specification

Practical reference for communicating with the hardened `lambda_kv_coproc` over
SPI: pinout, clocking/timing budget, byte-level protocol, address map + data
formats, status/decision/keep bit-fields, the compress-step FSM, address decode,
and a worked transaction.

- `lambda_kv_coproc_spec.tex` — source
- `lambda_kv_coproc_spec.pdf` — compiled (6 pages)

Compile: `tectonic lambda_kv_coproc_spec.tex` (or `pdflatex`). Derived from
`src/lambda_kv_coproc.sv` and `src/spi_loader.sv` at signoff.
