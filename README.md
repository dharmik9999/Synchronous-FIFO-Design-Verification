# Synchronous FIFO Design and Verification

A parameterized, single-clock synchronous FIFO implemented in synthesizable Verilog-2005, with a SystemVerilog testbench and reproducible PowerShell workflows.

The project demonstrates RTL design, occupancy-based flow control, functional verification, simulation automation, and generic logic synthesis.

**Design type:** Synchronous FIFO (single clock). This implementation does not include asynchronous FIFO clock-domain crossing or Gray-coded CDC synchronization.

---

## Architecture Overview

The FIFO architecture uses a circular memory buffer, independent read/write pointers, occupancy tracking, and synchronous control logic.

**[View FIFO Architecture Block Diagram](docs/ARCHITECTURE.md)**

The architecture documentation provides a detailed explanation of the internal modules, signal flow, and control behavior.

## Design Summary

The default configuration supports **16 entries of 8-bit data**.

Both `DATA_WIDTH` and `DEPTH` are configurable parameters, including support for depth one and non-power-of-two depths.

### Key Features

- Parameterized FIFO data width and depth.
- Single-clock synchronous FIFO operation.
- Circular read and write pointers with explicit wraparound.
- Occupancy tracking using a counter.
- Full and empty flag generation.
- Registered FIFO data output.
- Overflow and underflow indication.
- Active-low synchronous reset.
- Defined simultaneous read/write behavior.
- Support for directed and deterministic randomized testing.

### Read and Write Behavior

Requests are evaluated using occupancy immediately before each rising clock edge.

| FIFO State | Operation | Expected Behavior |
|---|---|---|
| Empty | Read | Rejected; underflow indicated |
| Empty | Write | Accepted |
| Empty | Simultaneous read/write | Write accepted; read rejected |
| Partially filled | Read | Oldest data returned |
| Partially filled | Write | Data stored if space is available |
| Full | Write only | Rejected; overflow indicated |
| Full | Simultaneous read/write | Oldest data returned; replacement write accepted |

The `dout` register retains its previous value when no read operation is accepted.

For the complete interface specification and edge-case behavior, see [PROJECT_SPEC.md](PROJECT_SPEC.md).

---

## RTL Design

The FIFO is implemented in synthesizable Verilog-2005.

**Main RTL source:** `rtl/sync_fifo.v`

The design uses:

- Parameterized memory storage.
- Explicitly bounded circular pointers.
- Occupancy-count-based status generation.
- Synchronous read and write control.
- Registered output and error flags.

The architecture and internal operation are documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Verification Methodology

**Testbench:** `tb/tb_sync_fifo.sv`

The SystemVerilog testbench uses an independent reference model and procedural scoreboard checks to compare actual FIFO behavior against expected behavior.

### Verification Scenarios

- Reset and initialization.
- FIFO fill and drain operations.
- Data ordering and integrity.
- Full and empty boundary conditions.
- Overflow and underflow requests.
- Simultaneous read/write operations.
- Read/write pointer wraparound.
- Reset during traffic.
- Deterministic randomized traffic.
- Multiple parameter configurations.
- Negative-control testing to check failure detection.

### Verification Features

- Directed test cases.
- Procedural self-checking scoreboard.
- Reference-model-based comparisons.
- Procedural coverage counters and checks.
- Simulation watchdog.
- Parameterized testbench configuration.

**Verification scope:** The testbench does not claim UVM implementation, SVA-based assertion coverage, formal verification, or exhaustive proof.

For detailed test methodology, see [VERIFICATION_PLAN.md](VERIFICATION_PLAN.md).

---

## Repository Structure

```text
Synchronous-FIFO-Design-Verification/
├── README.md
├── .gitignore
├── PROJECT_SPEC.md
├── VERIFICATION_PLAN.md
├── constraints/
│   └── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   └── WAVEFORM_GUIDE.md
├── rtl/
│   └── sync_fifo.v
├── tb/
│   ├── tb_sync_fifo.sv
│   └── netlist_timescale.v
├── scripts/
│   ├── common.ps1
│   ├── check_tools.ps1
│   ├── run_lint.ps1
│   ├── run_simulations.ps1
│   ├── run_regression.ps1
│   ├── generate_waveforms.ps1
│   ├── run_synthesis.ps1
│   ├── run_all.ps1
│   ├── write_summary.ps1
│   └── clean.ps1
├── reports/
│   └── EXECUTION_SUMMARY.md
└── results/
    ├── SAVED_EVIDENCE.md
    └── saved/
        ├── source_hashes.json
        └── validation_workflow_summary.json
```

Generated simulator binaries, temporary reports, large waveform outputs, and intermediate synthesis files are excluded from the published repository.

---

## Tools and Technologies

| Category | Tools / Languages |
|---|---|
| RTL Design | Verilog-2005 |
| Verification | SystemVerilog |
| Simulation | Icarus Verilog / VVP |
| Lint | Icarus Verilog, Verilator |
| Logic Synthesis | Yosys |
| Waveform Analysis | GTKWave (optional) |
| Automation | PowerShell |
| Diagram Support | Graphviz (optional) |
| Version Control | Git, GitHub |

Required tools must be installed separately.

The workflow uses tool discovery through `PATH` or environment-variable overrides configured in `scripts/common.ps1`.

---

## Running the Project

Open PowerShell in the repository root.

### 1. Check Available Tools

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_tools.ps1
```

### 2. Run Lint Checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_lint.ps1
```

### 3. Run Functional Simulations

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_simulations.ps1
```

### 4. Run Regression Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_regression.ps1
```

### 5. Generate Waveforms

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate_waveforms.ps1
```

### 6. Run Generic Synthesis

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_synthesis.ps1
```

### Complete Workflow

To execute the project's full validation workflow:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_all.ps1
```

Generated outputs are written to the configured `results/`, `reports/generated/`, and `waveforms/generated/` directories.

These generated outputs are excluded from normal Git tracking through `.gitignore`.

---

## Saved Validation Evidence

The repository includes selected historical verification evidence from **October 20, 2026**.

These numbers are from the saved original project handoff, not a fresh simulation run of the published copy.

| Verification Metric | Saved Reported Result |
|---|---|
| Simulation runs | 73 passing |
| Checked rising clock edges | 881,951 |
| Parameter configurations | 9 |
| Lint | Saved passing results |
| Generic Yosys synthesis | Saved synthesis results |
| Negative-control test | Reported failure correctly detected |

The recorded validation covers RTL simulations, regression testing, synthesized-netlist checks, and waveform generation.

For supporting information:

- [Saved Verification Evidence](results/SAVED_EVIDENCE.md)
- [Historical Execution Summary](reports/EXECUTION_SUMMARY.md)
- [Source Hash Manifest](results/saved/source_hashes.json)
- [Validation Workflow Summary](results/saved/validation_workflow_summary.json)

**Evidence limitation:** The saved validation results have not been independently reproduced for this public repository copy. Source revisions and tool environments should be checked before treating historical results as current.

---

## Design Scope and Limitations

This project focuses on RTL design and simulation-based functional verification.

It does not claim:

- Asynchronous FIFO clock-domain crossing.
- Gray-coded CDC synchronization.
- UVM-based verification.
- SVA-based assertion coverage.
- Formal verification or exhaustive proof.
- FPGA implementation.
- ASIC physical design or place-and-route.
- Standard-cell timing closure.
- Physical power or area measurements.

Yosys outputs represent technology-independent generic synthesis results, not measured silicon implementation characteristics.

---

## Learning Outcomes

This project provides practical experience with:

- Parameterized RTL design.
- FIFO architecture and circular buffering.
- Occupancy-based flow control.
- Boundary-condition handling.
- SystemVerilog testbench development.
- Self-checking scoreboards and reference models.
- Directed and randomized verification.
- Automated lint, simulation, regression, and generic synthesis workflows.
- Technical documentation and reproducible project organization.

---

## Author

**Dharmik Arvindbhai Mangukiya**

Aspiring RTL Design & Verification Engineer

Bengaluru, Karnataka, India

**GitHub:** https://github.com/dharmik9999

**Email:** mangukiyadharmik833@gmail.com

---

## License

No license is currently included.

A license may be added after confirming appropriate rights to distribute the project and selecting suitable terms.
