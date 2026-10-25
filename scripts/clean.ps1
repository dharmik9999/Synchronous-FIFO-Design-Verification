[CmdletBinding(SupportsShouldProcess=$true)]
param()
. "$PSScriptRoot\common.ps1"
# Fixed generated directories only. Validate all paths before removing anything.
$relative=@('results/tools','results/suite','results/regression','results/waveform',
    'results/lint','results/synthesis','results/validation','results/tmp','reports/generated','waveforms/generated')
$root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
$targets=@()
foreach ($item in $relative) {
    $target=[IO.Path]::GetFullPath((Join-Path $ProjectRoot $item))
    if (!$target.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe target: $target" }
    if (Test-Path -LiteralPath $target) {
        # Reject reparse points anywhere under the deletion target.
        $entries=@(Get-Item -LiteralPath $target -Force) + @(Get-ChildItem -LiteralPath $target -Force -Recurse)
        if ($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Refusing reparse point in $target" }
        $targets += $target
    }
}
foreach ($target in $targets) {
    if ($PSCmdlet.ShouldProcess($target,'Remove generated artifacts recursively')) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}
