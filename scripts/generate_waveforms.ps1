[CmdletBinding()]
param([ValidateRange(0,1000000)][int]$RandomCycles=200)
& "$PSScriptRoot\run_simulations.ps1" -Mode Waveform -RandomCycles $RandomCycles
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
