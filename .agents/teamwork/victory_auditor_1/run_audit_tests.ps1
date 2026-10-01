$root = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage"
$runner = "$root\dandelion_tool\tests\run_tests.ps1"

function Run-TierAudit {
    param([string]$Tier)
    Write-Host "================== AUDIT TIER: $Tier ==================" -ForegroundColor Cyan
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -Tier $Tier"
    $pinfo.WorkingDirectory = $root
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pinfo
    $proc.Start() | Out-Null
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    $exitCode = $proc.ExitCode
    Write-Host "Exit Code: $exitCode"
    if ($stderr) {
        Write-Host "STDERR: $stderr" -ForegroundColor Red
    }

    # Extract test summary
    $totalMatch = [regex]::Match($stdout, "TOTAL TESTS RUN\s*:\s*(\d+)")
    $passMatch  = [regex]::Match($stdout, "PASSED\s*:\s*(\d+)")
    $failMatch  = [regex]::Match($stdout, "FAILED\s*:\s*(\d+)")

    [PSCustomObject]@{
        Tier = $Tier
        ExitCode = $exitCode
        TotalTests = if ($totalMatch.Success) { [int]$totalMatch.Groups[1].Value } else { -1 }
        Passed = if ($passMatch.Success) { [int]$passMatch.Groups[1].Value } else { -1 }
        Failed = if ($failMatch.Success) { [int]$failMatch.Groups[1].Value } else { -1 }
        HasStdErr = (-not [string]::IsNullOrWhiteSpace($stderr))
    }
}

$results = @()
$results += Run-TierAudit -Tier "1"
$results += Run-TierAudit -Tier "2"
$results += Run-TierAudit -Tier "3"
$results += Run-TierAudit -Tier "4"
$results += Run-TierAudit -Tier "All"

Write-Host "`n================== INDEPENDENT EXECUTION AUDIT SUMMARY ==================" -ForegroundColor Green
$results | Format-Table -AutoSize
