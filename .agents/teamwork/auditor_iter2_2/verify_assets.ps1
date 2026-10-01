# Asset Verification Script
$ErrorActionPreference = "Stop"

$workspace = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage"

# 1. vbmeta.img
$vbPath = Join-Path $workspace "dandelion_tool\recovery\vbmeta.img"
$vbBytes = [System.IO.File]::ReadAllBytes($vbPath)
$vbSize = $vbBytes.Length
$vbMagic = [System.Text.Encoding]::ASCII.GetString($vbBytes, 0, 4)
$vbFlags = [System.BitConverter]::ToUInt32($vbBytes[123..120], 0).ToString("X8")
$vbSha = (Get-FileHash $vbPath -Algorithm SHA256).Hash

Write-Host "VBMETA_SIZE: $vbSize"
Write-Host "VBMETA_MAGIC: $vbMagic"
Write-Host "VBMETA_FLAGS: 0x$vbFlags"
Write-Host "VBMETA_SHA256: $vbSha"

# 2. recovery.img
$recPath = Join-Path $workspace "dandelion_tool\recovery\recovery.img"
$recBytes = [System.IO.File]::ReadAllBytes($recPath)
$recSize = $recBytes.Length
$recMagic = [System.Text.Encoding]::ASCII.GetString($recBytes, 0, 8)
$recSha = (Get-FileHash $recPath -Algorithm SHA256).Hash

Write-Host "RECOVERY_SIZE: $recSize"
Write-Host "RECOVERY_MAGIC: $recMagic"
Write-Host "RECOVERY_SHA256: $recSha"

# 3. Magisk-v26.4.apk
$apkPath = Join-Path $workspace "dandelion_tool\roms\Magisk-v26.4.apk"
$apkSize = (Get-Item $apkPath).Length
$apkHeaderBytes = [byte[]]::new(4)
$stream = [System.IO.File]::OpenRead($apkPath)
$null = $stream.Read($apkHeaderBytes, 0, 4)
$stream.Close()
$apkMagic = [System.Text.Encoding]::ASCII.GetString($apkHeaderBytes, 0, 2)
$apkSha = (Get-FileHash $apkPath -Algorithm SHA256).Hash

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
$arm64Entries = @($zip.Entries | Where-Object { $_.FullName -like "*arm64-v8a*" } | ForEach-Object { $_.FullName })
$totalEntries = $zip.Entries.Count
$zip.Dispose()

Write-Host "MAGISK_SIZE: $apkSize"
Write-Host "MAGISK_MAGIC: $apkMagic"
Write-Host "MAGISK_SHA256: $apkSha"
Write-Host "MAGISK_TOTAL_ENTRIES: $totalEntries"
Write-Host "MAGISK_ARM64_COUNT: $($arm64Entries.Count)"
Write-Host "MAGISK_ARM64_ENTRIES:"
foreach ($entry in $arm64Entries) {
    Write-Host "  $entry"
}
