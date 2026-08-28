# Chipathon 2026 submission checklist — Team A71 (Longhorn Silicon)

Track D (AI/LLM for circuits) · project: **Lambda KV-Cache Coprocessor (KVE + TIU)**.

## Deadlines (from the org schedule)

- **Aug 28, 2026 — "DRC Dry-run GDS to Channel Partner"** (Week 35: Verification &
  Final Chip Review). Our DRC-clean GDS is ready.
- **Final Submission (DRC-clean GDS to Channel Partner) — TBD** in the schedule;
  watch Discord `#chipathon-announcements`.

## Technical artifacts — DONE (on `main`)

- [x] `info.yaml` — pin list; matches the delivered padframe DEF (BV + BH) exactly.
- [x] `gds/lambda_kv_coproc.gds` — hardened, signoff-clean, labels `obs0..obs3` +
      `VDD/VSS` (no `obs_out[*]`).
- [x] `lvs_config.json` — `TOP_SOURCE = lambda_kv_coproc`, layout path correct.
- [x] Delivered DEF archived + reconciled (`def/`, commit `21819a4`).
- [x] CI green — `make sim-coproc` + `make coproc` reproduce on every push.
- [x] Documentation: `docs/LLM_APPROACH.md` (Track D), `docs/VERIFICATION.md`,
      `docs/INTEGRATION.md`, `README.md`.
- [x] Presentation slides (deck) — see the team's slide file / artifact.

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
- [ ] **Full author names / emails** — fill into `AUTHORS.md` (currently first names).
- [ ] **Demo video** — optional but recommended by the guidelines.

## Open questions to confirm with the org (Discord)

1. **Handoff mechanism** — is the DRC-dry-run/final GDS pulled from our repo
   (`info.yaml` says "data pulled from the default branch"), or handed to the channel
   partner separately? The delivered DEF implies the org already has our design.
2. **Repo of record** — does our design live in `LonghornSilicon/gf180-longhorn-tiu`
   (this repo), or must it be inside the forked padring repo?
3. **Final submission date** — currently TBD in the schedule.
4. **Which slot** — BV vs BH; the org selected both.

## Scoring (for emphasis)

Technical implementation 40 % · Innovation 30 % · Documentation 15 % ·
Presentation 15 %. The Track-D "designed by an LLM agent" story
(`docs/LLM_APPROACH.md`) is the innovation differentiator.
