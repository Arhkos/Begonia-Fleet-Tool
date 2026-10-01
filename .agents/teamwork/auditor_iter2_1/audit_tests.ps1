$lines = Get-Content ".\dandelion_tool\tests\test_dandelion.ps1"
$tests = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'Register-TestResult') {
        $fullCall = $lines[$i]
        $j = $i
        while ($fullCall -notmatch '-Details' -and $j -lt ($i + 5) -and $j -lt ($lines.Count - 1)) {
            $j++
            $fullCall += " " + $lines[$j]
        }
        $testId = if ($fullCall -match '-TestId\s+"([^"]+)"') { $matches[1] } else { "UNKNOWN" }
        $desc = if ($fullCall -match '-Description\s+"([^"]+)"') { $matches[1] } else { "UNKNOWN" }
        $passed = if ($fullCall -match '-Passed\s+([^\s]+)') { $matches[1] } else { "UNKNOWN" }
        $tests += [PSCustomObject]@{
            Line = $i + 1
            Id = $testId
            Description = $desc
            PassedVar = $passed
        }
    }
}

Write-Host "Total Register-TestResult lines: $($tests.Count)"
$groups = $tests | Group-Object Id
foreach ($g in $groups) {
    if ($g.Count -gt 1) {
        Write-Host "Duplicate ID: $($g.Name), Count: $($g.Count), Lines: $(($g.Group | ForEach-Object { $_.Line }) -join ', ')"
    }
}

$missing = @()
# Check if any tests defined in test_dandelion.ps1 were missed or if any tests are inside conditional blocks
Write-Host "All Unique IDs ($($groups.Count)):"
$groups | ForEach-Object { $_.Name } | Sort-Object | Out-String | Write-Host
