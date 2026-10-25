# Constraints boundary

This is technology-independent logic synthesis. There is no selected ASIC library,
FPGA device, clock target, pin assignment, place-and-route flow, or timing model.
No SDC timing constraints are applied. The testbench's 10 ns clock is stimulus,
not evidence of 100 MHz hardware timing closure. Add target-specific constraints
and memory macro collision requirements before physical implementation.
