[CmdletBinding()]
param([ValidateRange(0,1000000)][int]$RandomCycles=20000, [int[]]$Seeds=@(7,42,314159,987654321))
& "$PSScriptRoot\run_simulations.ps1" -Mode Regression -RandomCycles $RandomCycles -Seeds $Seeds
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
