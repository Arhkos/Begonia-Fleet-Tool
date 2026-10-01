<#
.SYNOPSIS
    Test Runner Entrypoint for dandelion_tool E2E Test Suite.
.DESCRIPTION
    Launches test_dandelion.ps1 with -NoProfile -ExecutionPolicy Bypass and propagates exit codes.
.PARAMETER Tier
    Specify which Tier to run: "1", "2", "3", "4", or "All" (default: "All").
.PARAMETER VerboseOutput
    Switch to output full test detail including passing assertions.
#>

[CmdletBinding()]
param (
    [ValidateSet("1", "2", "3", "4", "All")]
    [string]$Tier = "All",

    [switch]$VerboseOutput
)

$TestScript = Join-Path $PSScriptRoot "test_dandelion.ps1"

if (-not (Test-Path $TestScript)) {
    Write-Host "[-] ERROR: Test suite script not found at $TestScript" -ForegroundColor Red
    exit 1
}

$argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$TestScript`"",
    "-Tier", $Tier
)

if ($VerboseOutput) {
    $argList += "-VerboseOutput"
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "       STARTING E2E TEST RUNNER FOR DANDELION_TOOL (XIAOMI REDMI 10A)           " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Executing: powershell.exe $($argList -join ' ')" -ForegroundColor DarkGray

& powershell.exe @argList
$suiteExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
if ($suiteExitCode -eq 0) {
    Write-Host "  TEST RUN COMPLETE: ALL CHECKS PASSED (Exit Code: $suiteExitCode)" -ForegroundColor Green
} else {
    Write-Host "  TEST RUN COMPLETE: FAILURES DETECTED (Exit Code: $suiteExitCode)" -ForegroundColor Red
}
Write-Host "================================================================================" -ForegroundColor Cyan

exit $suiteExitCode
