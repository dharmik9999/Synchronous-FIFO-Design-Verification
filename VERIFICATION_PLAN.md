# Verification plan

## Strategy

Compile production RTL separately in Verilog-2005 mode. Run the SystemVerilog
testbench with Icarus/VVP. The independent reference model stores words in an
oldest-first array, shifts on a successful pop, then appends a successful push.
It does not duplicate the DUT's circular pointers. Read eligibility uses the
original population, so an empty simultaneous request cannot bypass new input.

Drive on falling edges. Check old outputs one nanosecond later to test stability
and synchronous reset behavior. Update the model at the next rising edge and
compare all six output fields one nanosecond later, after RTL nonblocking updates.
Case inequality detects X/Z on observable outputs after reset. Every mismatch
prints expected/actual values and calls `$fatal(1)`; a watchdog catches hangs.

## Requirements and evidence

| Requirement | Stimulus / check |
|---|---|
| Reset / reset priority | Reset held, requests asserted during reset, full reset, read reset |
| Synchronous reset | Pre-edge comparison while rst_n changes at the falling edge |
| Single write / single read | Known A5 word (width adjusted); occupancy and registered output checks |
| Ordering / integrity | Every accepted read compared to oldest model entry |
| Full / overflow | Fill, repeated rejected writes, drain and compare all remaining data |
| Empty / underflow | Drain, repeated rejected reads, verify held dout and error clearing |
| Pointer wrap | Four fill/stream/drain rounds, each streaming for 2*DEPTH+3 cycles at full |
| Simultaneous normal | All four request combinations at an interior occupancy when DEPTH>1 |
| Simultaneous full | Read old head and append new input, including same-address depth one |
| Simultaneous empty | Reject read, accept write, hold dout, assert underflow |
| Repeated transitions | At least four entries into full and empty are mandatory |
| Reset during traffic | Discard full/occupied model, verify no stale word after reset |
| Random traffic | Deterministic xorshift32, independent request bits and random data bits |
| Random reset | rst_n low when control bits [11:2] are zero (approximately 1/1024) |
| Parameterization | Nine configurations, covering widths below/above 32 and diverse depths |
| Error exit | Deliberately corrupt expected dout on cycle five; require nonzero VVP exit |
| Synthesized behavior | Repeat all directed tests plus 1,000 random cycles on each netlist |

## Matrix and seeds

| DATA_WIDTH | DEPTH | Purpose |
|---:|---:|---|
| 1 | 1 | Smallest legal configuration |
| 8 | 1 | Single-entry replacement with byte data |
| 1 | 2 | Minimum binary pointer width with two entries |
| 8 | 5 | Odd non-power-of-two depth |
| 8 | 10 | Even non-power-of-two depth |
| 8 | 16 | Default configuration |
| 16 | 17 | Pointer width boundary above a power of two |
| 32 | 3 | Wider data, shallow odd depth |
| 65 | 5 | Multiword-width random data generation |

Suite: seeds 1, 12345, 20261020, 5,000 random cycles per configuration/seed.
Regression: seeds 7, 42, 314159, 987654321, 20,000 random cycles per run.
Netlists: seed 20261020, 1,000 random cycles per configuration.
Waveform: default configuration, seed 20261020, 200 random cycles.
Directed sequences and a final drain run in addition to each random budget.

## Coverage gates

Each simulation must visit all reachable occupancy values and all reachable
crosses of {empty, middle, full} with {idle, read, write, both}. DEPTH=1 explicitly
excludes the four impossible middle bins. Accepted reads/writes must each exceed
four times DEPTH; resets while occupied, overflow, underflow, simultaneous empty/full,
output holds, and repeated full/empty transitions have mandatory coverage checks.
Counts appear in each `COVERAGE` log line. Failure to hit a required bin is fatal.

This is requirement-oriented functional coverage implemented in the testbench,
not a commercial coverage database or a measurement of source/branch/toggle coverage.
Wrap is exercised by directed operations beyond multiple storage revolutions and
checked via observed ordering; the scoreboard does not inspect internal pointers.

## Limitations

The finite regression is not exhaustive or formal. It does not verify arbitrary
parameter values, all possible data patterns/sequences, analog reset quality,
metastability, setup/hold margins, glitches, timing back-annotation, RAM macro
behavior, power, fault injection into DUT state, or post-route correctness.
Random seed zero is remapped to one to avoid xorshift's zero absorbing state.
The intentional checker error validates the failure path; it is not RTL mutation
coverage or a proof of checker completeness. No assertions assume X-valued inputs
are meaningful functional requests.
