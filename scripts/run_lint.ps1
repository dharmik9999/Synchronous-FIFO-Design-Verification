[CmdletBinding()]
param()
. "$PSScriptRoot\common.ps1"
$originalPath=$env:PATH
$originalRoot=$env:YOSYSHQ_ROOT
$originalVerilatorRoot=$env:VERILATOR_ROOT
$out=New-OutputDirectory 'results/lint'
$rows=@()
Save-Json @() (Join-Path $out 'summary.json')
try {
    $tools=Get-ToolPaths
    Require-Tool $tools 'Icarus'
    Enable-ToolEnvironment $tools
    foreach ($config in $Configurations) {
        $tag="w$($config.Width)_d$($config.Depth)"
        $rtl=Join-Path $ProjectRoot 'rtl/sync_fifo.v'
        [void](Invoke-LoggedTool $tools.Icarus @('-g2005','-Wall','-s','sync_fifo',"-Psync_fifo.DATA_WIDTH=$($config.Width)","-Psync_fifo.DEPTH=$($config.Depth)",'-tnull',$rtl) (Join-Path $out "$tag.icarus.log"))
        $status='UNAVAILABLE'
        if ($tools.Verilator) {
            [void](Invoke-LoggedTool $tools.Verilator @('--lint-only','--Wall','--language','1364-2005','--top-module','sync_fifo',"-GDATA_WIDTH=$($config.Width)","-GDEPTH=$($config.Depth)",$rtl) (Join-Path $out "$tag.verilator.log"))
            $status='PASS'
        }
        $rows += [pscustomobject]@{Width=$config.Width;Depth=$config.Depth;Icarus='PASS';Verilator=$status}
        Write-Host "LINT $tag Icarus=PASS Verilator=$status"
    }
    Save-Json $rows (Join-Path $out 'summary.json')
    if (!$tools.Verilator) { Write-Warning 'Verilator unavailable; Icarus checks completed. See tool inventory.' }
    $failure=Join-Path $out 'failure.json'
    if (Test-Path -LiteralPath $failure) { Remove-Item -LiteralPath $failure }
} catch {
    Save-Json ([pscustomobject]@{Status='FAIL';Error=$_.Exception.Message}) (Join-Path $out 'failure.json')
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { $env:PATH=$originalPath; $env:YOSYSHQ_ROOT=$originalRoot; $env:VERILATOR_ROOT=$originalVerilatorRoot }
