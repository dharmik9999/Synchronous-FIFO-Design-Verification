[CmdletBinding()]
param()
. "$PSScriptRoot\common.ps1"
$report=New-OutputDirectory 'reports/generated'
try {
    # Assign before normalizing to arrays: PS5 ConvertFrom-Json emits an array
    # as one pipeline item, whereas newer PowerShell enumerates it.
    $suite=Get-Content -LiteralPath (Join-Path $ProjectRoot 'results/suite/summary.json') -Raw | ConvertFrom-Json
    $regression=Get-Content -LiteralPath (Join-Path $ProjectRoot 'results/regression/summary.json') -Raw | ConvertFrom-Json
    $wave=Get-Content -LiteralPath (Join-Path $ProjectRoot 'results/waveform/summary.json') -Raw | ConvertFrom-Json
    $lint=Get-Content -LiteralPath (Join-Path $ProjectRoot 'results/lint/summary.json') -Raw | ConvertFrom-Json
    $synth=Get-Content -LiteralPath (Join-Path $ProjectRoot 'results/synthesis/summary.json') -Raw | ConvertFrom-Json
    $suite=@($suite); $regression=@($regression); $wave=@($wave); $lint=@($lint); $synth=@($synth)
    $negative=Get-Content -LiteralPath (Join-Path $ProjectRoot 'results/suite/negative_control.json') -Raw | ConvertFrom-Json
    if ($suite.Count -ne 27 -or $regression.Count -ne 36 -or $wave.Count -ne 1 -or $lint.Count -ne 9 -or $synth.Count -ne 9) {
        throw 'Incomplete full-workflow result matrix. Run run_all.ps1.'
    }
    if (@($suite+$regression+$wave | Where-Object Status -NE 'PASS').Count -gt 0 -or !$negative.ExpectedFailureDetected) { throw 'Simulation evidence contains a failure.' }
    if (@($synth | Where-Object { $_.Synthesis -ne 'PASS' -or $_.NetlistSimulation -ne 'PASS' }).Count -gt 0) { throw 'Synthesis evidence contains a failure.' }
    $suiteCycles=($suite | Measure-Object CheckedCycles -Sum).Sum
    $regressionCycles=($regression | Measure-Object CheckedCycles -Sum).Sum
    $netCycles=0
    foreach ($row in $synth) {
        $log=Get-Content -LiteralPath (Join-Path $row.Directory 'simulation.log') -Raw
        $match=[regex]::Match($log,'PASS W=\d+ D=\d+ SEED=\d+ RANDOM=\d+ CHECKED=(\d+)')
        if (!$match.Success) { throw "Missing netlist PASS in $($row.Directory)" }
        $netCycles += [int]$match.Groups[1].Value
    }
    $wavePath=Join-Path $ProjectRoot 'waveforms/generated/fifo_w8_d16.vcd'
    if (!(Test-Path -LiteralPath $wavePath) -or (Get-Item -LiteralPath $wavePath).Length -eq 0) { throw 'Missing waveform.' }
    $metrics=[pscustomobject]@{
        SuiteRuns=$suite.Count;SuiteCheckedCycles=$suiteCycles
        RegressionRuns=$regression.Count;RegressionCheckedCycles=$regressionCycles
        NetlistRuns=$synth.Count;NetlistCheckedCycles=$netCycles
        WaveformRuns=$wave.Count;WaveformCheckedCycles=$wave[0].CheckedCycles
        TotalCheckedCycles=($suiteCycles+$regressionCycles+$netCycles+$wave[0].CheckedCycles)
        NegativeControlExitCode=$negative.ExitCode
    }
    Save-Json $metrics (Join-Path $report 'metrics.json')
    $lines=@('# Execution summary','',
        'Generated from local JSON summaries and simulation logs. See results/validation/summary.json for execution timestamps.',
        '', '| Stage | Passing runs | Checked rising edges |','|---|---:|---:|',
        "| RTL suite | $($suite.Count) | $suiteCycles |",
        "| RTL regression | $($regression.Count) | $regressionCycles |",
        "| Synthesized netlist | $($synth.Count) | $netCycles |",
        "| Waveform | 1 | $($wave[0].CheckedCycles) |",
        "| Total | $($suite.Count+$regression.Count+$synth.Count+1) | $($metrics.TotalCheckedCycles) |",
        '',"Intentional checker failure detected with exit code $($negative.ExitCode).",'',
        '| Width | Depth | Icarus check | Verilator lint | Synthesis | Netlist test | Generic cells |',
        '|---:|---:|---|---|---|---|---:|')
    foreach ($row in $synth) {
        $l=$lint | Where-Object { $_.Width -eq $row.Width -and $_.Depth -eq $row.Depth }
        $lines += "| $($row.Width) | $($row.Depth) | $($l.Icarus) | $($l.Verilator) | $($row.Synthesis) | $($row.NetlistSimulation) | $($row.Cells) |"
    }
    $lines += @('','Cell counts are technology-independent structural counts. No physical area, timing, or power is measured.',
        'Finite functional simulation and synthesis checks are not formal verification.')
    $lines | Set-Content -LiteralPath (Join-Path $report 'EXECUTION_SUMMARY.md') -Encoding utf8
    $files=Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'rtl'),(Join-Path $ProjectRoot 'tb'),(Join-Path $ProjectRoot 'scripts') -File -Recurse
    $hashes=@($files | ForEach-Object { $hash=Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256; [pscustomobject]@{File=$_.FullName.Substring($ProjectRoot.Length+1);SHA256=$hash.Hash} })
    Save-Json $hashes (Join-Path $ProjectRoot 'results/validation/source_manifest.json')
    Write-Host "PASS evidence summary: $($metrics.TotalCheckedCycles) checked cycles."
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
