# Waveform interpretation

File: `waveforms/generated/fifo_w8_d16.vcd`, produced by the default 8 x 16 test.
The time precision is 1 ps; the stimulus clock period is 10 ns.

Add these signals from tb_sync_fifo: clk, rst_n, wr_en, rd_en, din, dout, count,
full, empty, overflow, underflow. From dut add wr_ptr, rd_ptr, read_accept,
write_accept. Set din/dout to hexadecimal and count/pointers to unsigned decimal.
The VCD also includes model signals for comparison; they are verification state,
not synthesized hardware.

## First directed operations

The testbench begins checking at the rising edge at 15 ns. There is an initial
reset edge at 5 ns before transaction counting begins. Values below are the
post-edge values for the default configuration.

| Checked cycle | Edge (ns) | Operation | count | dout (hex) | overflow | underflow |
|---:|---:|---|---:|---|---:|---:|
| 1 | 15 | Reset with both requests high | 0 | 00 | 0 | 0 |
| 2 | 25 | Reset held | 0 | 00 | 0 | 0 |
| 3 | 35 | Empty idle | 0 | 00 | 0 | 0 |
| 4 | 45 | Empty read rejected | 0 | 00 | 0 | 1 |
| 5 | 55 | Consecutive empty read rejected | 0 | 00 | 0 | 1 |
| 6 | 65 | Idle clears underflow | 0 | 00 | 0 | 0 |
| 7 | 75 | Write A5 | 1 | 00 | 0 | 0 |
| 8 | 85 | Idle; output holds | 1 | 00 | 0 | 0 |
| 9 | 95 | Read A5 | 0 | A5 | 0 | 0 |
| 10 | 105 | Empty read+write of 3C | 1 | A5 | 0 | 1 |
| 11 | 115 | Read the stored 3C | 0 | 3C | 0 | 0 |

At cycle ten, dout holds A5 because the read was illegal before the edge. That
held value is not another valid read transaction. The new 3C word is available
for an accepted read at the next edge. This is registered-read behavior, not bypass.

## Later cases to inspect

- **Full rejection:** when count=16 and only wr_en is high, count and wr_ptr hold;
  overflow rises and queued words remain unchanged.
- **Full simultaneous transfer:** both pointers advance, count remains 16, full
  remains high, and dout captures the old oldest word. The new input replaces
  the location just read without corrupting FIFO order.
- **Wrap:** pointers change from 15 to 0 on accepted operations. A depth-five
  custom run would wrap from 4 to 0, never enter 5..7.
- **Reset while full:** requests are ignored; after the edge count/dout/errors
  are zero, pointers are zero, empty=1. A subsequent read is rejected.
- **Error indicators:** consecutive illegal requests can hold a flag high for
  multiple cycles. They are not sticky; a non-rejecting edge clears the flag.

Acceptance wires are combinational functions of current occupancy. After an
edge changes count, they can immediately reflect eligibility for the *next*
edge. Interpret the transaction using their pre-edge values, not only the
post-edge waveform cursor value.

Waveform viewing is explanatory; the reference checker is the automated
pass/fail authority. The waveform is not a timing-analysis result or screenshot.
