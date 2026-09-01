# Demo video — shooting script & storyboard

**Lambda KV-Cache Coprocessor · Longhorn Silicon (A71) · Track D**

Target length **~2:45** (keep under 3 min). Format: 1080p screen capture +
voiceover. Everything on screen is a real asset that already exists in this repo
or the published deck — no mockups. Timecodes are guides, not hard cuts.

---

## Assets to capture first (shot list)

| # | Asset | How to get it |
|---|---|---|
| A | **Deck** (title, problem, architecture, agent, signoff, close slides) | Full-screen the published artifact and arrow-key through it, or open `docs/Longhorn_Silicon_Chipathon2026.pdf` |
| B | **Terminal: functional test** | Record `make sim-coproc` — ends on `COPROC SPI FUNCTIONAL TEST: ALL CHECKS PASS` |
| C | **Terminal: git log** | `git log --oneline -8` (shows the agent's commits: pin audit → BV reorder → DEF) |
| D | **Layout render** | `final_core/render/lambda_kv_coproc.png` (or the grayscale one in the deck) |
| E | **Signoff numbers** | Signoff slide of the deck, or `docs/VERIFICATION.md` table |
| F | **SPI protocol** | The frame/register-map page of `docs/spec/lambda_kv_coproc_spec.pdf` |

Optional b-roll: slowly scroll `src/lambda_kv_coproc.sv` and the spec's FSM diagram.

---

## Scene 1 — Hook (0:00–0:15)
**On screen:** Title slide (A) — LHS logo, "Lambda KV-Cache Coprocessor".
**VO:** "This is the Lambda KV-Cache Coprocessor. It compresses and prunes a
language model's KV cache in dedicated silicon — and it was taken from RTL all
the way to a tapeout-ready layout by an LLM coding agent."

## Scene 2 — The problem (0:15–0:42)
**On screen:** Statement slide "The KV-cache is the fastest-growing cost in LLM
decode" (A).
**VO:** "During decoding, a model re-reads its entire key-value cache for every
new token. That cache grows with context length and quickly dominates memory and
bandwidth — the host ends up spending its energy just moving the cache around."

## Scene 3 — What it does (0:42–1:12)
**On screen:** Architecture slide / block diagram (A). Optionally point at each
engine as named.
**VO:** "So we move that work to the edge of memory. Three engines sit behind a
four-wire SPI link: KVE rotates and compresses each value token to INT3, TIU
scores token importance and picks what to evict, and a precision gate decides
where full precision still matters. Six functional pins, four status bits — small
enough for a shared-reticle slot."

## Scene 4 — Track D: designed by an LLM agent (1:12–1:45)
**On screen:** Agent slide (A), then cut to the git log terminal (C) — let the
commit hashes and messages show (`b4722ee`, `a432f94`, `21819a4`).
**VO:** "Here's the Track-D part. An agent drove the whole physical-design flow:
it hardened the core, and when the pin-name audit failed, it diagnosed the root
cause, split a bus into scalar ports, fixed the power-net names, re-hardened, and
then re-scanned the GDS to confirm the labels actually changed. It reordered the
pads for our padframe slot and reconciled the delivered floorplan — every step
reproduced in CI."

## Scene 5 — It works (1:45–2:18)
**On screen:** Terminal running `make sim-coproc` (B); let the PASS lines land,
end on **ALL CHECKS PASS**. Cut to the signoff numbers (E), then the layout
render (D).
**VO:** "And it works. The self-checking SPI test passes end to end — eviction,
keep-tier, the INT3 codes, all of it. Signoff is clean across the board: DRC,
LVS, antenna, and XOR all zero. This is the real routed layout — a quarter of a
square millimeter on GlobalFoundries 180-nanometer."

*(On-screen callout for the terminal: the 7 `PASS` lines and*
*`COPROC SPI FUNCTIONAL TEST: ALL CHECKS PASS`.)*

## Scene 6 — Talking to it (2:18–2:35)
**On screen:** SPI frame + register-map page of the spec (F).
**VO:** "Driving it is simple: over SPI you write the value tokens and attention
masses, pulse start, poll status, and read the compressed records back — codes,
scales, and the eviction decision."

## Scene 7 — Close (2:35–2:45)
**On screen:** Closing slide (A) — LHS logo, "Chips, designed at Texas."
**VO:** "Signoff-clean, reproducible, and ready for the shared reticle. Longhorn
Silicon."

---

## Recording notes
- **Voiceover:** the VO above is ~330 words ≈ 2:40 at a calm pace. Trim Scene 3 or
  6 first if you need to hit 2:00.
- **Capture:** OBS or QuickTime screen recording at 1080p; record terminal and
  deck separately, then edit. For the deck, hide the browser chrome (present the
  artifact full-screen).
- **Terminal:** run in a large font; `make sim-coproc` takes a few seconds — keep
  it real-time or trim the compile line. `make coproc` (the full harden) is long;
  if you show it, speed it up 20–50× or just show the final signoff summary.
- **Honesty:** keep the calibrated framing — "RTL and signoff verified," not
  "silicon-proven." It reads as more credible, not less.
- **Export:** H.264 mp4, 1080p; keep it under ~150 MB so it uploads anywhere.

## Where it goes
No upload location is defined in the schedule; confirm on the Chipathon Discord
where demo videos / slides are collected (link it in issue #189 once known).
