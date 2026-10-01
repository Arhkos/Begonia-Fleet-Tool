$ps1Content = Get-Content 'dandelion_tool\dandelion_tool.ps1' -Raw -Encoding UTF8
$hasMenuOptions = ($ps1Content -match 'switch\s*\(\$choice\)' -or $ps1Content -match 'Show-Menu') -and 
                  ($ps1Content -match 'seccfg|Bootloader' -and $ps1Content -match 'recovery|vbmeta' -and $ps1Content -match 'ROM|Root')
Write-Output "T1.6.4 with single quotes: $hasMenuOptions"
