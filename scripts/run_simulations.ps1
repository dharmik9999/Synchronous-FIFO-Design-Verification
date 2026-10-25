[CmdletBinding()]
param(
    [ValidateSet('Suite','Regression','Waveform')][string]$Mode = 'Suite',
    [ValidateRange(0,1000000)][int]$RandomCycles = 5000,
    [int[]]$Seeds = @(1,12345,20261020)
)
. "$PSScriptRoot\common.ps1"
$originalPath=$env:PATH
$originalRoot=$env:YOSYSHQ_ROOT
$originalVerilatorRoot=$env:VERILATOR_ROOT
$rows=@()
$out=New-OutputDirectory ("results/" + $Mode.ToLower())
$summary=Join-Path $out 'summary.json'
Save-Json @() $summary
try {
    $tools=Get-ToolPaths
    Require-Tool $tools 'Icarus'
    Require-Tool $tools 'Vvp'
    Enable-ToolEnvironment $tools
    $configs=$Configurations
    if ($Mode -eq 'Waveform') {
        $configs=@(@{Width=8;Depth=16})
        $Seeds=@(20261020)
        $wave=New-OutputDirectory 'waveforms/generated'
    }
    foreach ($config in $configs) {
        $tag="w$($config.Width)_d$($config.Depth)"
        $binary=Join-Path $out "$tag.vvp"
        $compile=Join-Path $out "$tag.compile.log"
        $arguments=@('-g2012','-Wall','-s','tb_sync_fifo',
            "-Ptb_sync_fifo.DATA_WIDTH=$($config.Width)","-Ptb_sync_fifo.DEPTH=$($config.Depth)",
            '-o',$binary,(Join-Path $ProjectRoot 'rtl/sync_fifo.v'),(Join-Path $ProjectRoot 'tb/tb_sync_fifo.sv'))
        [void](Invoke-LoggedTool $tools.Icarus $arguments $compile)
        foreach ($seed in $Seeds) {
            $log=Join-Path $out "${tag}_seed${seed}.log"
            $args=@($binary,"+SEED=$seed","+CYCLES=$RandomCycles")
            if ($Mode -eq 'Waveform') { $args += "+VCD=$wave\fifo_w8_d16.vcd" }
            $code=Invoke-LoggedTool $tools.Vvp $args $log -AllowFailure
            $content=Get-Content -LiteralPath $log -Raw
            $matched=[regex]::Match($content,'PASS W=(\d+) D=(\d+) SEED=(-?\d+) RANDOM=(\d+) CHECKED=(\d+)')
            $pass=($code -eq 0 -and $matched.Success)
            $checked=if ($matched.Success) {[int]$matched.Groups[5].Value} else {0}
            $rows += [pscustomobject]@{Width=$config.Width;Depth=$config.Depth;Seed=$seed;RandomCycles=$RandomCycles;CheckedCycles=$checked;Status=$(if($pass){'PASS'}else{'FAIL'});ExitCode=$code;Log=$log}
            Save-Json $rows $summary
            if (!$pass) { throw "Simulation failed: $tag seed=$seed; see $log" }
            Write-Host "$Mode PASS $tag seed=$seed checked=$checked"
        }
    }
    # Prove that a checker mismatch propagates as a nonzero simulator exit.
    if ($Mode -eq 'Suite') {
        $negativeLog=Join-Path $out 'negative_control.log'
        $code=Invoke-LoggedTool $tools.Vvp @($binary,'+INJECT_ERROR','+CYCLES=0') $negativeLog -AllowFailure
        $detected=($code -ne 0 -and (Select-String -LiteralPath $negativeLog -Pattern 'Scoreboard mismatch' -Quiet))
        Save-Json ([pscustomobject]@{ExpectedFailureDetected=$detected;ExitCode=$code;Log=$negativeLog}) (Join-Path $out 'negative_control.json')
        if (!$detected) { throw 'Negative control failed to detect intentional scoreboard corruption.' }
        Write-Host "PASS negative control: intentional mismatch returned exit $code"
    }
    $failure=Join-Path $out 'failure.json'
    if (Test-Path -LiteralPath $failure) { Remove-Item -LiteralPath $failure }
} catch {
    Save-Json ([pscustomobject]@{Status='FAIL';Error=$_.Exception.Message}) (Join-Path $out 'failure.json')
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { $env:PATH=$originalPath; $env:YOSYSHQ_ROOT=$originalRoot; $env:VERILATOR_ROOT=$originalVerilatorRoot }
