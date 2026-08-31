# Chipathon 2026 submission checklist — Team A71 (Longhorn Silicon)

Track D (AI/LLM for circuits) · project: **Lambda KV-Cache Coprocessor (KVE + TIU)**.

## Deadlines (from the org schedule)

- Aug 28, 2026 — DRC dry-run GDS to channel partner + verification session. (Passed.)
- **Sept 4, 2026 — Final Chip Review** (review session; upload the deck + attend).
- **Sept 7, 2026 — FINAL SUBMISSION: DRC-clean GDS to channel partner.**

## Handoff mechanism (CONFIRMED)

The **final GDS is pulled automatically from this repo's `main` branch**, joined
with the other projects into a combined project, and sent to the channel partner.
There is no separate hand-off step — so the only requirement is that `main` holds
the correct, final, DRC-clean GDS at the Sept 7 deadline. It does today
(`gds/lambda_kv_coproc.gds`, verified byte-identical to the signoff-clean hardened
output). **Keep `main` green and do not break the GDS/`info.yaml` before Sept 7.**

## Technical artifacts — DONE (on `main`)

- [x] `info.yaml` — pin list; matches the delivered padframe DEF (BV + BH) exactly.
- [x] `gds/lambda_kv_coproc.gds` — hardened, signoff-clean, labels `obs0..obs3` +
      `VDD/VSS` (no `obs_out[*]`).
- [x] `lvs_config.json` — `TOP_SOURCE = lambda_kv_coproc`, layout path correct.
- [x] Delivered DEF archived + reconciled (`def/`, commit `21819a4`).
- [x] CI green — `make sim-coproc` + `make coproc` reproduce on every push.
- [x] Documentation: `docs/LLM_APPROACH.md` (Track D), `docs/VERIFICATION.md`,
      `docs/INTEGRATION.md`, `README.md`.
- [x] Presentation slides — `docs/Longhorn_Silicon_Chipathon2026.pdf` (+ `.html`).

## Requires a human (Chaithu) — cannot be done from the repo

- [ ] **One-time registration** — the org's Google form (per `REGISTERING.md`);
      confirm the team + all members are registered.
- [ ] **Discord** — join `discord.gg/bAQFg6UAsU`, set English-letter nicknames,
      watch `#chipathon-announcements`. (Our handle in `info.yaml`: `changa`.)
- [ ] **Project issue** — an issue on `sscs-ose/sscs-chipathon-2026` titled
      `[Track D] Longhorn Silicon: Lambda KV-Cache Coprocessor`, with a proposal
      link in the first comment. Confirm it exists / create it.
- [ ] **Forks** — team lead forks `Mauricio-xx/chipathon-2026-gf180mcu-padring`;
      members fork the lead's repo (per `REGISTERING.md`).
- [ ] **Abbreviated proposal slides (max 2 min)** uploaded to the org Google Drive
      folder. (The full deck exists; a 2-minute cut can be prepared on request.)
- [x] **Author** — `AUTHORS.md` lists Chaithu Talasila.
- [ ] **Demo video** — optional but recommended by the guidelines.

## Open questions to confirm with the org (Discord)

1. ~~Handoff mechanism~~ — CONFIRMED: pulled from `main`, combined, sent to the
   channel partner (see above). This repo is the repo of record.
2. **Which slot** — BV vs BH; the org selected both. (Doesn't change our GDS.)

## Scoring (for emphasis)

Technical implementation 40 % · Innovation 30 % · Documentation 15 % ·
Presentation 15 %. The Track-D "designed by an LLM agent" story
(`docs/LLM_APPROACH.md`) is the innovation differentiator.
