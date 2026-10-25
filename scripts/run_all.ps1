[CmdletBinding()]
param()
. "$PSScriptRoot\common.ps1"
$out=New-OutputDirectory 'results/validation'
$started=Get-Date -Format o
$shell=(Get-Process -Id $PID).Path
$rows=@()
foreach ($script in @('check_tools.ps1','run_lint.ps1','run_simulations.ps1','run_regression.ps1','generate_waveforms.ps1','run_synthesis.ps1','write_summary.ps1')) {
    Write-Host "Running $script"
    & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $script)
    $code=$LASTEXITCODE
    $rows += [pscustomobject]@{Script=$script;ExitCode=$code;Status=$(if($code -eq 0){'PASS'}else{'FAIL'})}
    Save-Json ([pscustomobject]@{Started=$started;Completed=(Get-Date -Format o);Steps=$rows}) (Join-Path $out 'summary.json')
    if ($code -ne 0) { Write-Error "$script failed; see results logs." -ErrorAction Continue; exit 1 }
}
Write-Host 'PASS complete validation workflow. See results/validation/summary.json.'
