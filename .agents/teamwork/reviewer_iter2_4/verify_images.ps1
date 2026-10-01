$vbmetaPath = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\recovery\vbmeta.img"
$recPath = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\recovery\recovery.img"
$magiskPath = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\roms\Magisk-v26.4.apk"

Write-Host "=== VBMETA.IMG INSPECTION ==="
if (Test-Path $vbmetaPath) {
    $vBytes = [System.IO.File]::ReadAllBytes($vbmetaPath)
    Write-Host "File size: $($vBytes.Length) bytes"
    $magic = [System.Text.Encoding]::ASCII.GetString($vBytes[0..3])
    Write-Host "Magic: $magic"
    Write-Host "Hex header (64 bytes):"
    Write-Host ([System.BitConverter]::ToString($vBytes[0..63]))
    
    # AVB 2.0 header parsing:
    # 0..3: Magic "AVB0" (0x41 0x56 0x42 0x30)
    # 4..7: Major version (uint32 big-endian)
    # 8..11: Minor version (uint32 big-endian)
    $major = [System.Net.IPAddress]::NetworkToHostOrder([System.BitConverter]::ToInt32($vBytes, 4))
    $minor = [System.Net.IPAddress]::NetworkToHostOrder([System.BitConverter]::ToInt32($vBytes, 8))
    Write-Host "AVB Version: $major.$minor"
    
    # Flags at offset 120 (0x78)
    $flags = [System.Net.IPAddress]::NetworkToHostOrder([System.BitConverter]::ToInt32($vBytes, 120))
    Write-Host "AVB Flags (offset 120 / 0x78): $flags"
} else {
    Write-Host "VBMeta file missing!"
}

Write-Host "`n=== RECOVERY.IMG INSPECTION ==="
if (Test-Path $recPath) {
    $rFileInfo = Get-Item $recPath
    Write-Host "File size: $($rFileInfo.Length) bytes"
    $stream = [System.IO.File]::OpenRead($recPath)
    $header = New-Object byte[] 2048
    $read = $stream.Read($header, 0, 2048)
    $stream.Close()
    
    $recMagic = [System.Text.Encoding]::ASCII.GetString($header[0..7])
    Write-Host "Magic (first 8 bytes): '$recMagic'"
    Write-Host "Hex header (64 bytes):"
    Write-Host ([System.BitConverter]::ToString($header[0..63]))
    
    # Check Android boot image header (ANDROID! or similar)
    if ($recMagic.StartsWith("ANDROID!")) {
        Write-Host "Standard Android Boot/Recovery Image format (ANDROID!)"
        $kernelSize = [System.BitConverter]::ToUInt32($header, 8)
        $kernelAddr = [System.BitConverter]::ToUInt32($header, 12)
        $ramdiskSize = [System.BitConverter]::ToUInt32($header, 16)
        $ramdiskAddr = [System.BitConverter]::ToUInt32($header, 20)
        $headerVersion = [System.BitConverter]::ToUInt32($header, 40)
        Write-Host "Kernel size: $kernelSize, Ramdisk size: $ramdiskSize, Header Version: $headerVersion"
    } else {
        Write-Host "Checking alternative signatures..."
        # Check if gzip / lz4 / cpio or raw partition
    }
} else {
    Write-Host "Recovery file missing!"
}

Write-Host "`n=== MAGISK APK INSPECTION ==="
if (Test-Path $magiskPath) {
    $mInfo = Get-Item $magiskPath
    Write-Host "File size: $($mInfo.Length) bytes"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($magiskPath)
    Write-Host "ZIP Entries count: $($zip.Entries.Count)"
    $arm64Entries = $zip.Entries | Where-Object { $_.FullName -like "*arm64*" -or $_.FullName -like "*aarch64*" -or $_.FullName -eq "lib/arm64-v8a/libmagisk64.so" -or $_.FullName -eq "lib/arm64-v8a/libmagiskinit.so" }
    Write-Host "ARM64 entries found: $($arm64Entries.Count)"
    foreach ($entry in $arm64Entries | Select-Object -First 10) {
        Write-Host "  - $($entry.FullName) ($($entry.Length) bytes)"
    }
    $zip.Dispose()
} else {
    Write-Host "Magisk APK missing!"
}
