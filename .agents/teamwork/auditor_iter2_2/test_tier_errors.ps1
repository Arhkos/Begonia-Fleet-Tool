# Check for any exceptions or ErrorRecords during Tier 1 and Tier 2 standalone
foreach ($t in @("1", "2", "3", "4")) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\run_tests.ps1" -Tier $t 2>&1
    $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
    Write-Host "Tier $t : Errors=$($errors.Count), ExitCode=$LASTEXITCODE"
}
