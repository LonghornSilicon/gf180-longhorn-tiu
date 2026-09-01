# Demo assets — drop-in terminal footage

Ready-made footage for the demo video (see ../demo_video_script.md, Scene 5).

| File | Use |
|---|---|
| `sim_coproc.gif` | animated: `make sim-coproc` typing out, 7 checks → ALL CHECKS PASS |
| `harden_summary.gif` | animated: condensed `make coproc` → all-zero signoff |
| `*_final.png` | the final frame as a static screenshot |
| `*.txt` | the plain text (for captions/overlays or re-recording) |

1280x720. Numbers are real (7,080 cells, 502.89x520.81 um / 0.262 mm2, signoff
all zero). Drop the GIFs onto a timeline, or re-record the real commands live
(`make sim-coproc`; `make coproc`) if you prefer native terminal capture.

## Full assembled video
`Lambda_KV_Coprocessor_demo.mp4` — a complete **~75 s, 1280x720** silent/captioned
cut: deck slides (subtle motion + cross-dissolves) + the two terminal animations,
in the order of `../demo_video_script.md`. No voiceover (add your own, or dub
against the script). Built with PyAV/x264; re-render via `build_video.py`.
