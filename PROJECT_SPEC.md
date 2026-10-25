# Design and Functional Verification of a Parameterized Synchronous FIFO Memory Using Verilog HDL

Version 1.0 — 20 October 2026

## Scope and legal parameters

`sync_fifo` is a single-clock FIFO with a circular storage array and a registered
read output. Defaults: DATA_WIDTH=8, DEPTH=16. Both are positive integer parameters.
DEPTH=1 and non-power-of-two depths are supported. Zero and negative values are
outside the interface contract and rejected by the verification environment;
there are no simulation-only parameter assertions in production RTL. Extremely
large values beyond practical elaboration resources or signed integer arithmetic
are outside this project's validated scope.

Pointer width is `max(1, ceil(log2(DEPTH)))`. Count width is
`max(1, ceil(log2(DEPTH+1)))`, representing every occupancy from zero through DEPTH.
These widths are derived, not independently overridable parameters.

## Interface

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
| clk | Input | 1 | Rising-edge clock |
| rst_n | Input | 1 | Active-low **synchronous** reset |
| wr_en | Input | 1 | Write request |
| rd_en | Input | 1 | Read request |
| din | Input | DATA_WIDTH | Word offered for write |
| dout | Output | DATA_WIDTH | Last accepted read word; zero after reset |
| full | Output | 1 | Current count equals DEPTH |
| empty | Output | 1 | Current count equals zero |
| count | Output | Derived | Current occupancy |
| overflow | Output | 1 | Write request rejected at the most recent edge |
| underflow | Output | 1 | Read request rejected at the most recent edge |

## Exact edge contract

Inputs must be valid around a rising clock edge; they are assumed known binary
values. Reset must be sampled low on at least one rising edge before normal use.
No defined power-up state is promised before reset.

With rst_n high, let C be the occupancy immediately **before** that edge:

```
read_accept  = rd_en && (C > 0)
write_accept = wr_en && ((C < DEPTH) || read_accept)
C_next       = C + write_accept - read_accept
overflow_next  = wr_en && !write_accept
underflow_next = rd_en && !read_accept
```

Acceptance is not a port: a controller can derive it from requests and the
pre-edge flags. After the edge, count and flags describe the updated occupancy.
An accepted read captures the pre-edge oldest word into dout. An accepted write
appends din. Only accepted operations advance their corresponding pointers.

| Pre-edge occupancy | wr_en | rd_en | Accepted operations | Count change | overflow / underflow |
|---|---:|---:|---|---:|---|
| Empty | 0 | 0 | None | 0 | 0 / 0 |
| Empty | 0 | 1 | None | 0 | 0 / 1 |
| Empty | 1 | 0 | Write | +1 | 0 / 0 |
| Empty | 1 | 1 | Write only | +1 | 0 / 1 |
| Between empty and full | 0 | 0 | None | 0 | 0 / 0 |
| Between empty and full | 0 | 1 | Read | -1 | 0 / 0 |
| Between empty and full | 1 | 0 | Write | +1 | 0 / 0 |
| Between empty and full | 1 | 1 | Read and write | 0 | 0 / 0 |
| Full | 0 | 0 | None | 0 | 0 / 0 |
| Full | 0 | 1 | Read | -1 | 0 / 0 |
| Full | 1 | 0 | None | 0 | 1 / 0 |
| Full | 1 | 1 | Read and write | 0 | 0 / 0 |

The middle four rows are unreachable for DEPTH=1. Even at depth one, simultaneous
requests while full read the old stored word and replace it with din.

## Output validity and reset

- dout changes only on accepted reads or synchronous reset. It holds its previous
  value on idle cycles, write-only cycles, and rejected reads.
- Held dout is **not** a new valid word. The consumer must use read acceptance;
  there is no separate dout_valid signal. This avoids reading stale data as a new transaction.
- The FIFO is not first-word-fall-through. A write to an empty FIFO does not update
  dout. A later accepted read is required, including after empty simultaneous requests.
- overflow and underflow are per-edge indicators, not sticky flags. Consecutive
  rejected requests keep them high on consecutive cycles; a non-rejecting edge clears them.
- When rst_n is low at the edge, both pointers, count, dout, overflow, and underflow
  become zero. empty becomes one and full becomes zero. Requests are ignored.
- Asserting reset between clock edges does not immediately change outputs.
- Memory contents are not cleared. Reset empties the logical FIFO, so uninitialized
  or previous contents are never accepted as readable data. New writes overwrite
  each location before it becomes eligible for a read.

## Pointer and collision rules

Each pointer advances to zero when its value is DEPTH-1, otherwise increments by
one using an explicitly sized constant. Natural binary overflow is not used to
implement modulo DEPTH. For DEPTH=1 the pointers remain zero.

At full occupancy the read and write pointers coincide. Nonblocking assignments
make a simultaneous read observe the old word while writing the new word into
that address. The supplied Yosys flow maps storage to generic flip-flops and logic;
the synthesized netlist is checked against the same behavioral contract. A future
RAM macro or FPGA block-RAM implementation must explicitly preserve old-data/read-first
collision semantics, or add logic to emulate them. Unspecified macro collisions
are not an acceptable replacement.

## Invariants and implementation boundary

After reset and every legal transaction sequence: 0 <= count <= DEPTH, pointers
are in 0..DEPTH-1, full and empty cannot both assert, and unread data remains in
arrival order. Rejected writes neither modify storage nor move the pointer.
The verification checks external consequences of these rules; it is not a formal proof.

This design has no clock-domain crossing, asynchronous reset, ECC, packet framing,
almost-full/almost-empty thresholds, timing constraints, or physical implementation.
