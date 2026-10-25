# Historical execution summary

**Saved evidence from the source handoff; not a fresh run of this repository copy.** Generated originally from local JSON summaries and simulation logs. Recorded workflow timestamps are retained in `results/saved/validation_workflow_summary.json`.

| Stage | Passing runs | Checked rising edges |
|---|---:|---:|
| RTL suite | 27 | 141472 |
| RTL regression | 36 | 728638 |
| Synthesized netlist | 9 | 11150 |
| Waveform | 1 | 691 |
| Total | 73 | 881951 |

Intentional checker failure detected with exit code 1.

| Width | Depth | Icarus check | Verilator lint | Synthesis | Netlist test | Generic cells |
|---:|---:|---|---|---|---|---:|
| 1 | 1 | PASS | PASS | PASS | PASS | 19 |
| 8 | 1 | PASS | PASS | PASS | PASS | 33 |
| 1 | 2 | PASS | PASS | PASS | PASS | 37 |
| 8 | 5 | PASS | PASS | PASS | PASS | 153 |
| 8 | 10 | PASS | PASS | PASS | PASS | 266 |
| 8 | 16 | PASS | PASS | PASS | PASS | 384 |
| 16 | 17 | PASS | PASS | PASS | PASS | 691 |
| 32 | 3 | PASS | PASS | PASS | PASS | 239 |
| 65 | 5 | PASS | PASS | PASS | PASS | 723 |

Cell counts are technology-independent structural counts. No physical area, timing, or power is measured.
Finite functional simulation and synthesis checks are not formal verification.


