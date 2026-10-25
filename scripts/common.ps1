# Shared helpers. No global settings or persistent environment changes.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:Configurations = @(
    @{Width=1;Depth=1}, @{Width=8;Depth=1}, @{Width=1;Depth=2},
    @{Width=8;Depth=5}, @{Width=8;Depth=10}, @{Width=8;Depth=16},
    @{Width=16;Depth=17}, @{Width=32;Depth=3}, @{Width=65;Depth=5}
)

function Find-Executable {
    param([string[]]$Candidates, [string]$Command)
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    $found = Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
    return $null
}

function Get-ToolPaths {
    $suiteCandidates = @($env:OSS_CAD_SUITE, $env:YOSYSHQ_ROOT)
    $suite = $null
    foreach ($candidate in $suiteCandidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\yosys.exe'))) {
            $suite = $candidate
            break
        }
    }
    $bin = if ($suite) { Join-Path $suite 'bin' } else { $ProjectRoot }
    return @{
        Suite = $suite
        Icarus = Find-Executable @($env:IVERILOG_EXE,"$bin\iverilog.exe") 'iverilog.exe'
        Vvp = Find-Executable @($env:VVP_EXE,"$bin\vvp.exe") 'vvp.exe'
        Yosys = Find-Executable @($env:YOSYS_EXE,"$bin\yosys.exe") 'yosys.exe'
        Verilator = Find-Executable @($env:VERILATOR_EXE,"$bin\verilator_bin.exe") 'verilator_bin.exe'
        GtkWave = Find-Executable @($env:GTKWAVE_EXE,"$bin\gtkwave.exe") 'gtkwave.exe'
        Dot = Find-Executable @($env:DOT_EXE,"$bin\dot.exe") 'dot.exe'
    }
}

function Enable-ToolEnvironment {
    param($Tools)
    if ($Tools.Suite) {
        $env:PATH = "$($Tools.Suite)\bin;$($Tools.Suite)\lib;" + $env:PATH
        $env:YOSYSHQ_ROOT = $Tools.Suite
        $env:VERILATOR_ROOT = Join-Path $Tools.Suite 'share\verilator'
    }
}

function Require-Tool {
    param($Tools, [string]$Name)
    if (!$Tools[$Name]) {
        throw "Required tool '$Name' is unavailable. Set its *_EXE override or OSS_CAD_SUITE; nothing was installed."
    }
}

function New-OutputDirectory {
    param([string]$RelativePath)
    $path = Join-Path $ProjectRoot $RelativePath
    [void](New-Item -ItemType Directory -Force -Path $path)
    return $path
}

function Invoke-LoggedTool {
    param([string]$Executable, [string[]]$Arguments, [string]$Log, [switch]$AllowFailure)
    # Argument arrays preserve spaces in file paths. Native stderr is captured as evidence.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 2>&1 | Out-File -LiteralPath $Log -Encoding utf8
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($code -ne 0 -and !$AllowFailure) {
        Get-Content -LiteralPath $Log -Tail 25 | Write-Host
        throw "Tool exited with code ${code}: $Executable. Log: $Log"
    }
    return $code
}

function Save-Json {
    param($Value, [string]$Path)
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8
}


