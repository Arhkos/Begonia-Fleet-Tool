$root = "c:\Users\Arhkos\Documents\antigravity\peaceful-babbage"
$vbPath = "$root\dandelion_tool\recovery\vbmeta.img"
$recPath = "$root\dandelion_tool\recovery\recovery.img"
$apkPath = "$root\dandelion_tool\roms\Magisk-v26.4.apk"

$vb = [System.IO.File]::ReadAllBytes($vbPath)
$vbMagic = [System.Text.Encoding]::ASCII.GetString($vb, 0, 4)
$vbFlags = [System.BitConverter]::ToUInt32($vb[123..120], 0).ToString('X8')
$vbHash = (Get-FileHash $vbPath -Algorithm SHA256).Hash

$rec = [System.IO.File]::ReadAllBytes($recPath)
$recMagic = [System.Text.Encoding]::ASCII.GetString($rec, 0, 8)
$recHash = (Get-FileHash $recPath -Algorithm SHA256).Hash

$apk = Get-Item $apkPath
$apkHash = (Get-FileHash $apk.FullName -Algorithm SHA256).Hash
$apkBytes = [System.IO.File]::ReadAllBytes($apk.FullName)
$apkMagic = [System.Text.Encoding]::ASCII.GetString($apkBytes, 0, 2)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk.FullName)
$arm64Entries = $zip.Entries | Where-Object { $_.FullName -like '*arm64-v8a*' } | Select-Object -ExpandProperty FullName
$zipCount = $zip.Entries.Count
$zip.Dispose()

[PSCustomObject]@{
    VBMetaLength = $vb.Length
    VBMetaMagic = $vbMagic
    VBMetaFlags = $vbFlags
    VBMetaSHA256 = $vbHash
    RecLength = $rec.Length
    RecMagic = $recMagic
    RecSHA256 = $recHash
    ApkLength = $apk.Length
    ApkMagic = $apkMagic
    ApkSHA256 = $apkHash
    TotalZipEntries = $zipCount
    Arm64Count = $arm64Entries.Count
    Arm64Entries = ($arm64Entries -join ', ')
} | Format-List
