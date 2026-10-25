# Saved validation evidence

**Historical evidence only — this is not a fresh run of the GitHub-ready copy.** The saved source handoff records its final Windows PowerShell workflow on 20 October 2026. No simulation, lint, or synthesis was run while creating this curated copy.

The source handoff reports:

| Stage | Reported passing runs | Checked rising edges |
|---|---:|---:|
| RTL directed/random suite | 27 | 141,472 |
| Extended RTL regression | 36 | 728,638 |
| Generic synthesized-netlist simulation | 9 | 11,150 |
| Default waveform run | 1 | 691 |
| **Total** | **73** | **881,951** |

The saved handoff also reports Icarus Verilog-2005 compatibility checks and Verilator lint across nine width/depth configurations, plus a deliberate checker-corruption negative control that exited nonzero. See [`saved/validation_workflow_summary.json`](saved/validation_workflow_summary.json) for the recorded workflow stages and [`../reports/EXECUTION_SUMMARY.md`](../reports/EXECUTION_SUMMARY.md) for the saved configuration table. [`saved/source_hashes.json`](saved/source_hashes.json) preserves the saved SHA-256 fingerprints for the RTL and testbench. The per-run logs and synthesis outputs were omitted from this curated copy.

The reported Yosys cell counts are generic structural counts. They are not silicon area, timing, power, or evidence of physical implementation. The finite simulations are not formal verification or exhaustive proof.

