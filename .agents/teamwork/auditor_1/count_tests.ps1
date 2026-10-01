$content = Get-Content "dandelion_tool\tests\test_dandelion.ps1" -Raw
$matches = [regex]::Matches($content, '-TestId\s+"([^"]+)"')
$ids = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique | Sort-Object
Write-Host "Total Unique Test IDs defined: $($ids.Count)"
Write-Host ($ids -join ", ")
