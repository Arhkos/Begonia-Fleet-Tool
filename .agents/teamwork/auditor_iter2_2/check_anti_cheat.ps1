# Clean Anti-Cheat and Registration Summary
$ErrorActionPreference = "Stop"

$testFile = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1"
$content = Get-Content $testFile

$hardcodedMatches = @()
$testCalls = @()

for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i]
    if ($line -match 'Register-TestResult') {
        $testCalls += [PSCustomObject]@{
            LineNumber = $i + 1
            Line = $line.Trim()
        }
        if ($line -match '-Passed\s+\$true\b' -or $line -match '-Passed\s+1\b') {
            $hardcodedMatches += [PSCustomObject]@{
                LineNumber = $i + 1
                Line = $line.Trim()
            }
        }
    }
}

$sourceIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($tc in $testCalls) {
    if ($tc.Line -match '-TestId\s+"([^"]+)"') {
        $null = $sourceIds.Add($matches[1])
    }
}

# Run runner quietly
$output = & "powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\run_tests.ps1" -Tier All 2>&1

$totalLine = $output | Where-Object { $_ -match 'TOTAL TESTS RUN\s*:\s*(\d+)' }
$passedLine = $output | Where-Object { $_ -match 'PASSED\s*:\s*(\d+)' }
$failedLine = $output | Where-Object { $_ -match 'FAILED\s*:\s*(\d+)' }

Write-Host "=== ANTI-CHEAT & REGISTRATION AUDIT SUMMARY ==="
Write-Host "TOTAL_REGISTER_CALLS_IN_SOURCE: $($testCalls.Count)"
Write-Host "HARDCODED_PASSES_FOUND: $($hardcodedMatches.Count)"
Write-Host "UNIQUE_TEST_IDS_IN_SOURCE: $($sourceIds.Count)"
Write-Host "RUNNER_TOTAL_REPORTED: $totalLine"
Write-Host "RUNNER_PASSED_REPORTED: $passedLine"
Write-Host "RUNNER_FAILED_REPORTED: $failedLine"
