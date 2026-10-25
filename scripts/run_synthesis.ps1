[CmdletBinding()]
param([switch]$DefaultOnly)
. "$PSScriptRoot\common.ps1"
$originalPath=$env:PATH
$originalRoot=$env:YOSYSHQ_ROOT
$originalVerilatorRoot=$env:VERILATOR_ROOT
$out=New-OutputDirectory 'results/synthesis'
$report=New-OutputDirectory 'reports/generated'
$rows=@()
Save-Json @() (Join-Path $out 'summary.json')
Push-Location -LiteralPath $ProjectRoot
try {
    $tools=Get-ToolPaths
    Require-Tool $tools 'Yosys'
    Require-Tool $tools 'Icarus'
    Require-Tool $tools 'Vvp'
    Enable-ToolEnvironment $tools
    $configs=$Configurations
    if ($DefaultOnly) { $configs=@(@{Width=8;Depth=16}) }
    foreach ($config in $configs) {
        $tag="w$($config.Width)_d$($config.Depth)"
        $dir=New-OutputDirectory "results/synthesis/$tag"
        # Yosys scripts use forward slashes and quoted absolute file paths.
        $rtl=(Join-Path $ProjectRoot 'rtl/sync_fifo.v').Replace('\','/')
        $prefix=$dir.Replace('\','/')
        $lines=@(
            "read_verilog `"$rtl`"",
            "chparam -set DATA_WIDTH $($config.Width) -set DEPTH $($config.Depth) sync_fifo",
            'hierarchy -check -top sync_fifo',
            'proc', 'opt', 'check -assert',
            'select -assert-none t:$dlatch t:$adlatch t:$dlatchsr',
            'memory_collect',
            "tee -o `"$prefix/memory_stat.json`" stat -json",
            "write_json `"$prefix/memory.json`""
        )
        if ($config.Width -eq 8 -and $config.Depth -eq 16) {
            # show's -prefix parser retains quotes; a relative path avoids spaces.
            $lines += 'show -format dot -prefix reports/generated/fifo_inferred sync_fifo'
        }
        $lines += @(
            'synth -top sync_fifo -noabc',
            'check -assert',
            'select -assert-none t:$dlatch t:$adlatch t:$dlatchsr t:$_DLATCH_*',
            "tee -o `"$prefix/cell_stat.json`" stat -json",
            "write_verilog -noattr `"$prefix/sync_fifo_netlist.v`"",
            "write_json `"$prefix/sync_fifo_netlist.json`""
        )
        $ys=Join-Path $dir 'synth.ys'
        $lines | Set-Content -LiteralPath $ys -Encoding ascii
        [void](Invoke-LoggedTool $tools.Yosys @('-s',$ys) (Join-Path $dir 'yosys.log'))
        $binary=Join-Path $dir 'netlist.vvp'
        [void](Invoke-LoggedTool $tools.Icarus @('-g2012','-Wall','-DNETLIST','-s','tb_sync_fifo',"-Ptb_sync_fifo.DATA_WIDTH=$($config.Width)","-Ptb_sync_fifo.DEPTH=$($config.Depth)",'-o',$binary,(Join-Path $ProjectRoot 'tb/netlist_timescale.v'),(Join-Path $dir 'sync_fifo_netlist.v'),(Join-Path $ProjectRoot 'tb/tb_sync_fifo.sv')) (Join-Path $dir 'compile.log'))
        $simLog=Join-Path $dir 'simulation.log'
        [void](Invoke-LoggedTool $tools.Vvp @($binary,'+SEED=20261020','+CYCLES=1000') $simLog)
        if (!(Select-String -LiteralPath $simLog -Pattern '^PASS W=' -Quiet)) { throw "Missing netlist PASS: $tag" }
        $stats=Get-Content -LiteralPath (Join-Path $dir 'cell_stat.json') -Raw | ConvertFrom-Json
        $module=$stats.modules.PSObject.Properties | Select-Object -First 1 -ExpandProperty Value
        $rows += [pscustomobject]@{Width=$config.Width;Depth=$config.Depth;Synthesis='PASS';NetlistSimulation='PASS';Cells=$module.num_cells;CellTypes=$module.num_cells_by_type;Directory=$dir}
        Save-Json $rows (Join-Path $out 'summary.json')
        Write-Host "SYNTHESIS + NETLIST PASS $tag cells=$($module.num_cells)"
    }
    $dotFile=Join-Path $report 'fifo_inferred.dot'
    if ($tools.Dot -and (Test-Path -LiteralPath $dotFile)) {
        [void](Invoke-LoggedTool $tools.Dot @('-Tsvg',$dotFile,'-o',(Join-Path $report 'fifo_inferred.svg')) (Join-Path $out 'graphviz.log'))
    } else { Write-Host 'Graphviz not available; reproducible DOT schematic source retained.' }
    $failure=Join-Path $out 'failure.json'
    if (Test-Path -LiteralPath $failure) { Remove-Item -LiteralPath $failure }
} catch {
    Save-Json ([pscustomobject]@{Status='FAIL';Error=$_.Exception.Message}) (Join-Path $out 'failure.json')
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { Pop-Location; $env:PATH=$originalPath; $env:YOSYSHQ_ROOT=$originalRoot; $env:VERILATOR_ROOT=$originalVerilatorRoot }
