# Check for any exceptions or ErrorRecords during test execution
$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\run_tests.ps1" -Tier All 2>&1

$errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
Write-Host "ERROR_RECORDS_COUNT: $($errors.Count)"
if ($errors.Count -gt 0) {
    foreach ($err in $errors) {
        Write-Host "  Error: $($err.Exception.GetType().FullName) - $($err.Exception.Message)"
    }
} else {
    Write-Host "Zero ErrorRecords detected during full suite execution."
}
