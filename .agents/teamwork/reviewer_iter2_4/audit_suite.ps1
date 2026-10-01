$suitePath = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1"
$lines = [System.IO.File]::ReadAllLines($suitePath)

$tests = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match 'Register-TestResult\s+-TestId\s+"([^"]+)"\s+-Description\s+"([^"]+)"') {
        $tests += [PSCustomObject]@{
            Line = $i + 1
            Id = $matches[1]
            Desc = $matches[2]
        }
    }
}

Write-Host "Total tests found in source: $($tests.Count)"
$tests | Format-Table -AutoSize | Out-String | Write-Host
