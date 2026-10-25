[CmdletBinding()]
param()
. "$PSScriptRoot\common.ps1"
$originalPath = $env:PATH
$originalRoot = $env:YOSYSHQ_ROOT
$originalVerilatorRoot = $env:VERILATOR_ROOT
try {
    $tools = Get-ToolPaths
    Enable-ToolEnvironment $tools
    $out = New-OutputDirectory 'results/tools'
    $records = @()
    foreach ($name in @('Icarus','Vvp','Yosys','Verilator','GtkWave','Dot')) {
        $exe = $tools[$name]
        if (!$exe) {
            Write-Host "MISSING $name (optional tools do not block other workflows)"
            $records += [pscustomobject]@{Tool=$name;Path=$null;Status='MISSING';Version=$null}
            continue
        }
        # Avoid opening a GUI for GTKWave; existence is sufficient here.
        if ($name -eq 'GtkWave') {
            $version = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
            $status = 'FOUND (GUI not launched)'
        } else {
            $arg = if ($name -eq 'Verilator') {'--version'} else {'-V'}
            $log = Join-Path $out "$name.log"
            $code = Invoke-LoggedTool $exe @($arg) $log -AllowFailure
            # Build a plain string: Windows PowerShell 5 otherwise serializes
            # Get-Content's attached provider metadata recursively in JSON.
            $version = '{0}' -f (Get-Content -LiteralPath $log | Select-Object -First 1)
            $status = if ($code -eq 0) {'AVAILABLE'} else {"VERSION_EXIT_$code"}
        }
        Write-Host "$name : $status : $exe : $version"
        $records += [pscustomobject]@{Tool=$name;Path=$exe;Status=$status;Version=$version}
    }
    Save-Json $records (Join-Path $out 'inventory.json')
} finally { $env:PATH=$originalPath; $env:YOSYSHQ_ROOT=$originalRoot; $env:VERILATOR_ROOT=$originalVerilatorRoot }
