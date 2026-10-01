$errs = @()
$out = & ".\dandelion_tool\tests\test_dandelion.ps1" -Tier All 2>&1
foreach ($item in $out) {
    if ($item -is [System.Management.Automation.ErrorRecord]) {
        $errs += $item
    }
}
Write-Host "POWERSHELL_ERROR_COUNT=$($errs.Count)"
if ($errs.Count -gt 0) {
    foreach ($e in $errs) {
        Write-Host "EXCEPTION: $($e.Exception.Message)"
        Write-Host "AT: $($e.InvocationInfo.PositionMessage)"
    }
}
