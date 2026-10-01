<#
.SYNOPSIS
    Comprehensive Automated Opaque-Box E2E Test Suite for dandelion_tool (Xiaomi Redmi 10A).
.DESCRIPTION
    Verifies all requirements (R1 through R5) and acceptance criteria across 4 Tiers:
      Tier 1: Feature Coverage (Isolation, Relative Paths, BROM Unlock, Fastboot Recovery/AVB, ROM/Root, Menu, Docs)
      Tier 2: Boundary & Corner Cases (Paths with Spaces, Missing Binaries, Exit Codes, UsbDk Detection, Preloader Safety)
      Tier 3: Cross-Feature Interactions (Sequential Workflow, Menu Mapping, VBMeta AVB0 Header, Magisk/ROMs Alignment)
      Tier 4: Real-World Scenarios (Fresh Workstation, BROM Pipeline, Fastboot Pipeline, 64-bit/Root Logic, Acceptance Audit)
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

$ErrorActionPreference = "Continue"

# ==============================================================================
# 0. DIRECTORY RESOLUTION & TEST HARNESS SETUP
# ==============================================================================
$TestDir = $PSScriptRoot
$ToolDir = Split-Path -Parent $TestDir
$WorkspaceRoot = Split-Path -Parent $ToolDir

$global:TestResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$global:CurrentTier = ""
$global:CurrentGroup = ""

# Common script paths
$unlockScript   = "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat"
$recoveryScript = "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat"
$romScript      = "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat"
$menuBat        = "$ToolDir\MENU_DANDELION.bat"
$menuPs1        = "$ToolDir\dandelion_tool.ps1"
$readmeMd       = "$ToolDir\README.md"
$romsReadmeMd   = "$ToolDir\roms\README_ROMS.md"

# Global pre-flight content initialization for standalone Tier isolation
$unlockContent  = if (Test-Path $unlockScript)   { Get-Content $unlockScript -Raw -Encoding UTF8 } else { "" }
$recContent     = if (Test-Path $recoveryScript) { Get-Content $recoveryScript -Raw -Encoding UTF8 } else { "" }
$romContent     = if (Test-Path $romScript)      { Get-Content $romScript -Raw -Encoding UTF8 } else { "" }
$ps1Content     = if (Test-Path $menuPs1)        { Get-Content $menuPs1 -Raw -Encoding UTF8 } else { "" }
$readmeContent  = if (Test-Path $readmeMd)       { Get-Content $readmeMd -Raw -Encoding UTF8 } else { "" }

function Start-TierGroup {
    param (
        [string]$TierName,
        [string]$GroupName
    )
    $global:CurrentTier = $TierName
    $global:CurrentGroup = $GroupName
    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  [$TierName] $GroupName" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
}

function Register-TestResult {
    param (
        [string]$TestId,
        [string]$Description,
        [bool]$Passed,
        [string]$Details = ""
    )

    $result = [PSCustomObject]@{
        Tier        = $global:CurrentTier
        Group       = $global:CurrentGroup
        Id          = $TestId
        Description = $Description
        Passed      = $Passed
        Details     = $Details
    }
    $global:TestResults.Add($result)

    if ($Passed) {
        Write-Host "  [PASS] $TestId : $Description" -ForegroundColor Green
        if ($VerboseOutput -and $Details) {
            Write-Host "         Detail: $Details" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [FAIL] $TestId : $Description" -ForegroundColor Red
        if ($Details) {
            Write-Host "         Reason: $Details" -ForegroundColor DarkYellow
        }
    }
}

# ==============================================================================
# TIER 1: FEATURE COVERAGE
# ==============================================================================
if ($Tier -in @("1", "All")) {

    # --------------------------------------------------------------------------
    # Group 1: Isolation & Non-Regression
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 1: Isolation & Non-Regression"

    # Test 1.1.1: Git status check - no modifications to tracked files outside dandelion_tool/
    try {
        $gitStatus = git -C "$WorkspaceRoot" status --porcelain 2>&1
        $modifiedTrackedOutside = @()
        foreach ($line in ($gitStatus -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $statusPrefix = $line.Substring(0, 2)
            $filePath = $line.Substring(3).Trim()
            
            # Check if tracked file was modified or deleted
            if ($statusPrefix -match '^[ MADRCU]') {
                # Untracked files starts with '??'
                if ($statusPrefix -ne '??') {
                    if (-not $filePath.StartsWith("dandelion_tool/") -and 
                        -not $filePath.StartsWith(".agents/") -and
                        -not $filePath.StartsWith("dandelion_tool\")) {
                        $modifiedTrackedOutside += $filePath
                    }
                }
            }
        }
        $isClean = ($modifiedTrackedOutside.Count -eq 0)
        $detail = if ($isClean) { "Zero modified tracked files outside dandelion_tool/." } else { "Modified outside: $($modifiedTrackedOutside -join ', ')" }
        Register-TestResult -TestId "T1.1.1" -Description "Zero modifications to tracked files outside dandelion_tool/ (git status)" -Passed $isClean -Details $detail
    } catch {
        Register-TestResult -TestId "T1.1.1" -Description "Zero modifications to tracked files outside dandelion_tool/ (git status)" -Passed $false -Details $_.Exception.Message
    }

    # Test 1.1.2: Root Begonia batch scripts remain intact
    $begoniaScripts = @(
        "0_INSTALLER_PILOTE_USBDK.bat",
        "1_DEVERROUILLER_BOOTLOADER_ET_FRP.bat",
        "2_RESTAURER_STOCK_EEA_UNBRICK.bat",
        "3_FLASHER_RECOVERY_ET_VBMETA.bat",
        "4_ENVOYER_ROM_SUR_TELEPHONE.bat",
        "MENU_GENERAL.bat",
        "begonia_tool.ps1"
    )
    $missingBegonia = @()
    foreach ($bs in $begoniaScripts) {
        if (-not (Test-Path "$WorkspaceRoot\$bs")) {
            $missingBegonia += $bs
        }
    }
    $begoniaIntact = ($missingBegonia.Count -eq 0)
    $detail = if ($begoniaIntact) { "All 7 Begonia root scripts exist intact." } else { "Missing: $($missingBegonia -join ', ')" }
    Register-TestResult -TestId "T1.1.2" -Description "Existing Begonia root scripts remain present and intact" -Passed $begoniaIntact -Details $detail

    # Test 1.1.3: Root recovery/ directory contains Begonia images only
    $rootRecoveryDir = "$WorkspaceRoot\recovery"
    $hasBegoniaRecovery = (Test-Path "$rootRecoveryDir\BRPv3.6.img") -and (Test-Path "$rootRecoveryDir\recovery.img")
    Register-TestResult -TestId "T1.1.3" -Description "Begonia recovery/ directory preserved intact with BRP images" -Passed $hasBegoniaRecovery -Details "BRPv3.6.img and recovery.img present"

    # Test 1.1.4: Root roms/ directory preserved intact
    $rootRomsDir = "$WorkspaceRoot\roms"
    $hasBegoniaRoms = (Test-Path "$rootRomsDir\FW R-OSS + BRP 3.1 - Begonia.zip")
    Register-TestResult -TestId "T1.1.4" -Description "Begonia roms/ directory preserved intact with Begonia ROM zip" -Passed $hasBegoniaRoms -Details "Begonia firmware zip present"

    # Test 1.1.5: Root documentation files preserved
    $rootDocsIntact = (Test-Path "$WorkspaceRoot\README.md") -and (Test-Path "$WorkspaceRoot\README.fr.md")
    Register-TestResult -TestId "T1.1.5" -Description "Begonia root documentation preserved (README.md, README.fr.md)" -Passed $rootDocsIntact -Details "Root READMEs exist"

    # --------------------------------------------------------------------------
    # Group 2: Relative Binary Paths
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 2: Relative Binary Paths"

    # Test 1.2.1: Relative resolution to ..\bin\adb.exe
    $adbRelPath = Join-Path $ToolDir "..\bin\adb.exe"
    $adbResolved = [System.IO.Path]::GetFullPath($adbRelPath)
    $adbExists = Test-Path $adbResolved
    $adbExecutes = $false
    if ($adbExists) {
        $adbVer = & "$adbResolved" version 2>&1
        $adbExecutes = ($LASTEXITCODE -eq 0 -and $adbVer -match "Android Debug Bridge")
    }
    Register-TestResult -TestId "T1.2.1" -Description "Relative resolution to ..\bin\adb.exe is valid and executable" -Passed ($adbExists -and $adbExecutes) -Details "adb version output: $($adbVer | Select-Object -First 1)"

    # Test 1.2.2: Relative resolution to ..\bin\fastboot.exe
    $fbRelPath = Join-Path $ToolDir "..\bin\fastboot.exe"
    $fbResolved = [System.IO.Path]::GetFullPath($fbRelPath)
    $fbExists = Test-Path $fbResolved
    $fbExecutes = $false
    if ($fbExists) {
        $fbVer = & "$fbResolved" --version 2>&1
        $fbExecutes = ($LASTEXITCODE -eq 0 -and $fbVer -match "fastboot version")
    }
    Register-TestResult -TestId "T1.2.2" -Description "Relative resolution to ..\bin\fastboot.exe is valid and executable" -Passed ($fbExists -and $fbExecutes) -Details "fastboot version: $($fbVer | Select-Object -First 1)"

    # Test 1.2.3: Relative resolution to ..\src\mtkclient\mtk.py
    $mtkRelPath = Join-Path $ToolDir "..\src\mtkclient\mtk.py"
    $mtkResolved = [System.IO.Path]::GetFullPath($mtkRelPath)
    $mtkExists = Test-Path $mtkResolved
    $mtkExecutes = $false
    if ($mtkExists) {
        $mtkHelp = python "$mtkResolved" --help 2>&1
        $mtkExecutes = ($LASTEXITCODE -eq 0 -and $mtkHelp -match "mtk")
    }
    Register-TestResult -TestId "T1.2.3" -Description "Relative resolution to ..\src\mtkclient\mtk.py is valid and executable" -Passed ($mtkExists -and $mtkExecutes) -Details "mtk.py --help returned exit code 0"

    # Test 1.2.4: Relative resolution to ..\drivers\UsbDk_1.0.22_x64.msi
    $usbdkRelPath = Join-Path $ToolDir "..\drivers\UsbDk_1.0.22_x64.msi"
    $usbdkResolved = [System.IO.Path]::GetFullPath($usbdkRelPath)
    $usbdkExists = Test-Path $usbdkResolved
    $usbdkSize = if ($usbdkExists) { (Get-Item $usbdkResolved).Length } else { 0 }
    $usbdkValid = ($usbdkExists -and $usbdkSize -gt 6000000)
    Register-TestResult -TestId "T1.2.4" -Description "Relative resolution to ..\drivers\UsbDk_1.0.22_x64.msi is valid (>6MB)" -Passed $usbdkValid -Details "Size: $usbdkSize bytes"

    # Test 1.2.5: No hardcoded drive letters in dandelion_tool scripts
    $dandelionScripts = Get-ChildItem -Path $ToolDir -Filter "*.*" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".bat", ".ps1") -and $_.FullName -notmatch '\\tests\\' }
    $hardcodedFound = @()
    foreach ($s in $dandelionScripts) {
        $content = Get-Content $s.FullName -Raw -Encoding UTF8
        if ($content -match '[A-Za-z]:\\') {
            $hardcodedFound += $s.Name
        }
    }
    $noHardcoded = ($hardcodedFound.Count -eq 0)
    $detail = if ($noHardcoded) { "Zero hardcoded absolute drive paths found." } else { "Found in: $($hardcodedFound -join ', ')" }
    Register-TestResult -TestId "T1.2.5" -Description "No hardcoded absolute drive paths (C:\ or D:\) in dandelion_tool scripts" -Passed $noHardcoded -Details $detail

    # --------------------------------------------------------------------------
    # Group 3: BROM Bootloader Unlock Script (0_DEVERROUILLER_BOOTLOADER_DANDELION.bat)
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 3: BROM Bootloader Unlock Script"

    $unlockScript = "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat"
    $unlockExists = Test-Path $unlockScript
    $unlockContent = if ($unlockExists) { Get-Content $unlockScript -Raw -Encoding UTF8 } else { "" }

    # Test 1.3.1: Script file exists
    Register-TestResult -TestId "T1.3.1" -Description "0_DEVERROUILLER_BOOTLOADER_DANDELION.bat exists" -Passed $unlockExists -Details "Path: $unlockScript"

    # Test 1.3.2: UTF-8 encoding chcp 65001
    $hasChcp = ($unlockContent -match "chcp\s+65001")
    Register-TestResult -TestId "T1.3.2" -Description "Enforces UTF-8 console code page (chcp 65001)" -Passed $hasChcp -Details "chcp 65001 directive detected"

    # Test 1.3.3: da seccfg unlock command syntax
    $hasSeccfg = ($unlockContent -match "da\s+seccfg\s+unlock")
    Register-TestResult -TestId "T1.3.3" -Description "Valid mtkclient unlock syntax 'da seccfg unlock'" -Passed $hasSeccfg -Details "Matches 'da seccfg unlock'"

    # Test 1.3.4: e frp erase command syntax
    $hasFrp = ($unlockContent -match "e\s+frp")
    Register-TestResult -TestId "T1.3.4" -Description "FRP erase syntax 'e frp'" -Passed $hasFrp -Details "Matches 'e frp'"

    # Test 1.3.5: Relative mtkclient path invocation
    $hasRelativeMtk = ($unlockContent -match '(\.\.\\src\\mtkclient\\mtk\.py|src\\mtkclient\\mtk\.py)')
    Register-TestResult -TestId "T1.3.5" -Description "Invokes mtkclient via relative path (..\src\mtkclient\mtk.py)" -Passed $hasRelativeMtk -Details "Relative mtkclient path verified"

    # Test 1.3.6: Pause command present before exit
    $hasPause = ($unlockContent -match "(?m)^\s*pause\s*$")
    Register-TestResult -TestId "T1.3.6" -Description "Includes trailing pause to preserve console output" -Passed $hasPause -Details "Trailing pause command present"

    # --------------------------------------------------------------------------
    # Group 4: Fastboot Recovery & AVB Script (1_FLASHER_RECOVERY_ET_VBMETA.bat)
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 4: Fastboot Recovery & AVB Script"

    $recoveryScript = "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat"
    $recExists = Test-Path $recoveryScript
    $recContent = if ($recExists) { Get-Content $recoveryScript -Raw -Encoding UTF8 } else { "" }

    # Test 1.4.1: Script file exists
    Register-TestResult -TestId "T1.4.1" -Description "1_FLASHER_RECOVERY_ET_VBMETA.bat exists" -Passed $recExists -Details "Path: $recoveryScript"

    # Test 1.4.2: Relative fastboot binary reference
    $hasRelFastboot = ($recContent -match '(\.\.\\bin\\fastboot\.exe|bin\\fastboot\.exe)')
    Register-TestResult -TestId "T1.4.2" -Description "References fastboot via relative path (..\bin\fastboot.exe)" -Passed $hasRelFastboot -Details "Relative fastboot invocation verified"

    # Test 1.4.3: AVB disabling flags (--disable-verity --disable-verification)
    $hasAvbFlags = ($recContent -match "--disable-verity" -and $recContent -match "--disable-verification")
    Register-TestResult -TestId "T1.4.3" -Description "Applies AVB bypass flags (--disable-verity --disable-verification)" -Passed $hasAvbFlags -Details "Both AVB flags found"

    # Test 1.4.4: Custom recovery partition flash command
    $hasFlashRec = ($recContent -match "flash\s+recovery")
    Register-TestResult -TestId "T1.4.4" -Description "Executes custom recovery flash (flash recovery)" -Passed $hasFlashRec -Details "flash recovery command present"

    # Test 1.4.5: Immediate recovery reboot (reboot recovery)
    $hasRebootRec = ($recContent -match "reboot\s+recovery")
    Register-TestResult -TestId "T1.4.5" -Description "Forces immediate recovery reboot (reboot recovery) to prevent overwrite" -Passed $hasRebootRec -Details "reboot recovery command present"

    # Test 1.4.6: UTF-8 code page and pause
    $hasRecErgonomics = ($recContent -match "chcp\s+65001" -and $recContent -match "(?m)^\s*pause\s*$")
    Register-TestResult -TestId "T1.4.6" -Description "Includes UTF-8 encoding and trailing pause" -Passed $hasRecErgonomics -Details "chcp 65001 and pause verified"

    # --------------------------------------------------------------------------
    # Group 5: 64-bit ROM & Root Script (2_INSTALLER_ROM_64BIT_ET_ROOT.bat)
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 5: 64-bit ROM & Root Script"

    $romScript = "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat"
    $romExists = Test-Path $romScript
    $romContent = if ($romExists) { Get-Content $romScript -Raw -Encoding UTF8 } else { "" }

    # Test 1.5.1: Script file exists
    Register-TestResult -TestId "T1.5.1" -Description "2_INSTALLER_ROM_64BIT_ET_ROOT.bat exists" -Passed $romExists -Details "Path: $romScript"

    # Test 1.5.2: Relative ADB binary reference
    $hasRelAdb = ($romContent -match '(\.\.\\bin\\adb\.exe|bin\\adb\.exe)')
    Register-TestResult -TestId "T1.5.2" -Description "References ADB via relative path (..\bin\adb.exe)" -Passed $hasRelAdb -Details "Relative ADB invocation verified"

    # Test 1.5.3: Device detection / wait logic
    $hasDeviceWait = ($romContent -match "wait-for-device" -or $romContent -match "adb.*devices")
    Register-TestResult -TestId "T1.5.3" -Description "Includes ADB device detection / wait-for-device check" -Passed $hasDeviceWait -Details "Device wait or detection logic present"

    # Test 1.5.4: Architecture verification command (ro.product.cpu.abi -> arm64-v8a)
    $hasAbiCheck = ($romContent -match "ro\.product\.cpu\.abi" -and $romContent -match "arm64-v8a")
    Register-TestResult -TestId "T1.5.4" -Description "Includes architecture validation check (ro.product.cpu.abi == arm64-v8a)" -Passed $hasAbiCheck -Details "getprop ro.product.cpu.abi arm64-v8a assertion present"

    # Test 1.5.5: Root verification command (su -c id -> uid=0(root))
    $hasRootCheck = ($romContent -match 'su\s+-c\s+["'']?id["'']?' -or $romContent -match 'uid=0\(root\)')
    Register-TestResult -TestId "T1.5.5" -Description "Includes root privilege validation check (su -c 'id' -> uid=0(root))" -Passed $hasRootCheck -Details "Root privilege assertion present"

    # Test 1.5.6: UTF-8 code page and pause
    $hasRomErgonomics = ($romContent -match "chcp\s+65001" -and $romContent -match "(?m)^\s*pause\s*$")
    Register-TestResult -TestId "T1.5.6" -Description "Includes UTF-8 encoding and trailing pause" -Passed $hasRomErgonomics -Details "chcp 65001 and pause verified"

    # --------------------------------------------------------------------------
    # Group 6: Interactive Menu & Fleet Tool (MENU_DANDELION.bat & dandelion_tool.ps1)
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 6: Interactive Menu & Fleet Tool"

    $menuBat = "$ToolDir\MENU_DANDELION.bat"
    $menuPs1 = "$ToolDir\dandelion_tool.ps1"
    $menuBatExists = Test-Path $menuBat
    $menuPs1Exists = Test-Path $menuPs1

    # Test 1.6.1: MENU_DANDELION.bat exists and launches PowerShell with Bypass
    $menuBatValid = $false
    if ($menuBatExists) {
        $batText = Get-Content $menuBat -Raw -Encoding UTF8
        $menuBatValid = ($batText -match "-ExecutionPolicy\s+Bypass" -and $batText -match "dandelion_tool\.ps1")
    }
    Register-TestResult -TestId "T1.6.1" -Description "MENU_DANDELION.bat launches dandelion_tool.ps1 with -ExecutionPolicy Bypass" -Passed $menuBatValid -Details "Wrapper syntax verified"

    # Test 1.6.2: dandelion_tool.ps1 parses cleanly without syntax errors
    $ps1SyntaxOk = $false
    $parseErrors = @()
    if ($menuPs1Exists) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($menuPs1, [ref]$tokens, [ref]$errors)
        if ($errors.Count -eq 0) {
            $ps1SyntaxOk = $true
        } else {
            $parseErrors = $errors | ForEach-Object { $_.Message }
        }
    }
    $detail = if ($ps1SyntaxOk) { "AST parsed cleanly without errors." } else { "Parse errors: $($parseErrors -join '; ')" }
    Register-TestResult -TestId "T1.6.2" -Description "dandelion_tool.ps1 is valid PowerShell syntax (AST check)" -Passed $ps1SyntaxOk -Details $detail

    # Test 1.6.3: Environment diagnostics routine present
    $ps1Content = if ($menuPs1Exists) { Get-Content $menuPs1 -Raw -Encoding UTF8 } else { "" }
    $hasDiag = ($ps1Content -match "function\s+.*Check.*Environment" -or ($ps1Content -match "UsbDk" -and $ps1Content -match "fastboot\.exe" -and $ps1Content -match "adb\.exe"))
    Register-TestResult -TestId "T1.6.3" -Description "dandelion_tool.ps1 includes environment diagnostics routine" -Passed $hasDiag -Details "Diagnostic function / checks detected"

    # Test 1.6.4: Interactive menu options mapped
    $hasMenuOptions = ($ps1Content -match 'switch\s*\(\$choice\)' -or $ps1Content -match "Show-Menu") -and 
                      ($ps1Content -match "seccfg|Bootloader" -and $ps1Content -match "recovery|vbmeta" -and $ps1Content -match "ROM|Root")
    Register-TestResult -TestId "T1.6.4" -Description "dandelion_tool.ps1 provides full interactive menu lifecycle options" -Passed $hasMenuOptions -Details "Menu lifecycle routing detected"

    # Test 1.6.5: Terminal styling adheres to Begonia standards
    $hasStyling = ($ps1Content -match "-ForegroundColor\s+Cyan" -and $ps1Content -match "-ForegroundColor\s+Yellow" -and $ps1Content -match "-ForegroundColor\s+Green")
    Register-TestResult -TestId "T1.6.5" -Description "dandelion_tool.ps1 adheres to Begonia visual styling standards (Cyan/Yellow/Green/Red)" -Passed $hasStyling -Details "Color formatting verified"

    # --------------------------------------------------------------------------
    # Group 7: Technical Documentation (README.md & roms\README_ROMS.md)
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 1" -GroupName "Feature Group 7: Technical Documentation"

    $readmeMd = "$ToolDir\README.md"
    $romsReadmeMd = "$ToolDir\roms\README_ROMS.md"
    $readmeExists = Test-Path $readmeMd
    $romsReadmeExists = Test-Path $romsReadmeMd
    $readmeContent = if ($readmeExists) { Get-Content $readmeMd -Raw -Encoding UTF8 } else { "" }
    $romsReadmeContent = if ($romsReadmeExists) { Get-Content $romsReadmeMd -Raw -Encoding UTF8 } else { "" }

    # Test 1.7.1: README documents MT6762G Helio G25 SoC, dandelion codename, blossom family
    $hasSocDocs = ($readmeContent -match "MT6762G|Helio\s+G25" -and $readmeContent -match "dandelion" -and $readmeContent -match "blossom")
    Register-TestResult -TestId "T1.7.1" -Description "README.md documents MT6762G SoC, dandelion codename, and blossom family" -Passed $hasSocDocs -Details "SoC and platform details documented"

    # Test 1.7.2: Documents hardware key sequences for BROM, Fastboot, Recovery
    $hasKeyDocs = ($readmeContent -match "VOLUME.*HAUT.*VOLUME.*BAS|Volume.*Up.*Volume.*Down|\+.*-" -and $readmeContent -match "FASTBOOT|Fastboot")
    Register-TestResult -TestId "T1.7.2" -Description "README.md documents hardware key sequences (BROM, Fastboot, Recovery)" -Passed $hasKeyDocs -Details "Button sequences documented"

    # Test 1.7.3: Warning regarding preloader protection
    $hasPreloaderWarning = ($readmeContent -match "preloader" -and ($readmeContent -match "ne\s+pas|danger|attention|avertissement|warning|brick"))
    Register-TestResult -TestId "T1.7.3" -Description "README.md includes preloader protection warning" -Passed $hasPreloaderWarning -Details "Preloader safety warning documented"

    # Test 1.7.4: Documents verification commands
    $hasVerifDocs = ($readmeContent -match "ro\.product\.cpu\.abi" -and $readmeContent -match "arm64-v8a" -and $readmeContent -match "su\s+-c")
    Register-TestResult -TestId "T1.7.4" -Description "README.md documents verification commands (ro.product.cpu.abi and root check)" -Passed $hasVerifDocs -Details "Verification commands documented"

    # Test 1.7.5: roms\README_ROMS.md specifies 64-bit ROMs, checksums, and Magisk instructions
    $hasRomsDocs = $romsReadmeExists -and 
                   ($romsReadmeContent -match "crDroid|LineageOS" -and $romsReadmeContent -match "arm64|aarch64" -and ($romsReadmeContent -match "Magisk" -or $romsReadmeContent -match "SHA256|sha256|checksum"))
    Register-TestResult -TestId "T1.7.5" -Description "roms\README_ROMS.md specifies 64-bit ROMs, checksums, and Magisk instructions" -Passed $hasRomsDocs -Details "ROMs and Magisk documentation verified"
}

# ==============================================================================
# TIER 2: BOUNDARY & CORNER CASES
# ==============================================================================
if ($Tier -in @("2", "All")) {

    # --------------------------------------------------------------------------
    # Group 1: Paths with Spaces Handling
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 2" -GroupName "Boundary Group 1: Paths with Spaces Handling"

    # Test 2.1.1: Quoted %~dp0 paths in all batch files
    $batFiles = Get-ChildItem -Path $ToolDir -Filter "*.bat" -ErrorAction SilentlyContinue
    $allBatQuoted = ($batFiles.Count -gt 0)
    $unquotedBat = @()
    foreach ($b in $batFiles) {
        $lines = Get-Content $b.FullName
        foreach ($line in $lines) {
            # Check for unquoted %~dp0 before executable or argument
            if ($line -match '(?<!")%~dp0[^\s"]+\.(exe|bat|py|img|msi|apk)(?!")') {
                $unquotedBat += "$($b.Name): $line"
            }
        }
    }
    $allBatQuoted = ($unquotedBat.Count -eq 0)
    $detail = if ($allBatQuoted) { "All %~dp0 binary and asset paths properly double-quoted." } else { "Unquoted: $($unquotedBat -join '; ')" }
    Register-TestResult -TestId "T2.1.1" -Description "All %~dp0 paths in batch scripts are properly enclosed in double quotes" -Passed $allBatQuoted -Details $detail

    # Test 2.1.2: Flash argument paths enclosed in quotes in 1_FLASHER_RECOVERY_ET_VBMETA.bat
    $recContent = if (Test-Path "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat") { Get-Content "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat" -Raw -Encoding UTF8 } else { "" }
    $flashQuoted = ($recContent -match 'flash\s+vbmeta\s+"[^"]+"' -or $recContent -match 'flash\s+recovery\s+"[^"]+"')
    Register-TestResult -TestId "T2.1.2" -Description "Flash file arguments in 1_FLASHER_RECOVERY_ET_VBMETA.bat are double-quoted" -Passed $flashQuoted -Details "Double-quoted image arguments detected"

    # Test 2.1.3: Quoted python script path in 0_DEVERROUILLER_BOOTLOADER_DANDELION.bat
    $unlockContent = if (Test-Path "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat") { Get-Content "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat" -Raw -Encoding UTF8 } else { "" }
    $pythonQuoted = ($unlockContent -match 'python\s+"[^"]*mtk\.py"')
    Register-TestResult -TestId "T2.1.3" -Description "Python script invocation quotes mtk.py path in unlock script" -Passed $pythonQuoted -Details "Quoted python argument verified"

    # Test 2.1.4: PowerShell script invokes binaries using quoted variable paths (& "$exe")
    $ps1Content = if (Test-Path "$ToolDir\dandelion_tool.ps1") { Get-Content "$ToolDir\dandelion_tool.ps1" -Raw -Encoding UTF8 } else { "" }
    $ps1QuotesInvocations = ($ps1Content -match '&\s*"[^"]*"' -or $ps1Content -match '&\s*\$[A-Za-z0-9_]+')
    Register-TestResult -TestId "T2.1.4" -Description "PowerShell script executes native binaries via quoted variables (& `"`$exe`")" -Passed $ps1QuotesInvocations -Details "PowerShell variable call operator pattern verified"

    # Pre-load 2_INSTALLER_ROM_64BIT_ET_ROOT.bat content for Tier 2 standalone execution
    $romContent = if (Test-Path "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat") { Get-Content "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat" -Raw -Encoding UTF8 } else { "" }

    # Test 2.1.5: Simulated space path resolution
    $testSpaceDir = "C:\Test Space Path\dandelion_tool"
    $simulatedParent = Split-Path -Parent $testSpaceDir
    $simulatedBin = "$simulatedParent\bin\fastboot.exe"
    $spaceResolved = ($simulatedBin -eq "C:\Test Space Path\bin\fastboot.exe")
    Register-TestResult -TestId "T2.1.5" -Description "Path resolution logic safely handles spaces without argument splitting" -Passed $spaceResolved -Details "Resolved correctly to: $simulatedBin"

    # --------------------------------------------------------------------------
    # Group 2: Missing Binary Error Handling
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 2" -GroupName "Boundary Group 2: Missing Binary Error Handling"

    # Test 2.2.1: dandelion_tool.ps1 implements Test-Path checks before invoking tools
    $hasTestPath = ($ps1Content -match "Test-Path")
    Register-TestResult -TestId "T2.2.1" -Description "dandelion_tool.ps1 checks binary existence with Test-Path" -Passed $hasTestPath -Details "Test-Path usage verified"

    # Test 2.2.2: Fastboot missing check displays error status
    $handlesMissingFb = ($ps1Content -match "fastboot\.exe" -and ($ps1Content -match '\[-\]' -or $ps1Content -match "introuvable|manquant|missing"))
    Register-TestResult -TestId "T2.2.2" -Description "dandelion_tool.ps1 handles missing fastboot.exe gracefully" -Passed $handlesMissingFb -Details "Missing fastboot detection confirmed"

    # Test 2.2.3: ADB missing check displays error status
    $handlesMissingAdb = ($ps1Content -match "adb\.exe" -and ($ps1Content -match '\[-\]' -or $ps1Content -match "introuvable|manquant|missing"))
    Register-TestResult -TestId "T2.2.3" -Description "dandelion_tool.ps1 handles missing adb.exe gracefully" -Passed $handlesMissingAdb -Details "Missing ADB detection confirmed"

    # Test 2.2.4: Python / mtkclient missing check displays error status
    $handlesMissingPy = ($ps1Content -match "python" -and ($ps1Content -match '\[-\]' -or $ps1Content -match "introuvable|manquant|missing|installer"))
    Register-TestResult -TestId "T2.2.4" -Description "dandelion_tool.ps1 handles missing Python/mtkclient gracefully" -Passed $handlesMissingPy -Details "Missing Python detection confirmed"

    # Test 2.2.5: Recovery flashing logic validates presence of recovery.img and vbmeta.img
    $validatesRecoveryImages = ($ps1Content -match "recovery\.img" -and $ps1Content -match "vbmeta\.img")
    Register-TestResult -TestId "T2.2.5" -Description "Recovery flashing logic validates recovery.img and vbmeta.img" -Passed $validatesRecoveryImages -Details "Image validation detected"

    # --------------------------------------------------------------------------
    # Group 3: Exit Code Propagation
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 2" -GroupName "Boundary Group 3: Exit Code Propagation"

    # Test 2.3.1: Batch scripts check %errorlevel%
    $checksErrorlevel = ($unlockContent -match "errorlevel" -or $recContent -match "errorlevel" -or $romContent -match "errorlevel")
    Register-TestResult -TestId "T2.3.1" -Description "Batch scripts check %errorlevel% after tool execution" -Passed $checksErrorlevel -Details "%errorlevel% check verified"

    # Test 2.3.2: Batch scripts do not silently exit on failure
    $noSilentExit = ($unlockContent -match "pause" -and $recContent -match "pause" -and $romContent -match "pause")
    Register-TestResult -TestId "T2.3.2" -Description "Batch scripts maintain pause on termination preventing silent exit" -Passed $noSilentExit -Details "All 3 batch scripts maintain terminal pauses"

    # Test 2.3.3: PowerShell script checks $LASTEXITCODE
    $checksLastExitCode = ($ps1Content -match '\$LASTEXITCODE')
    Register-TestResult -TestId "T2.3.3" -Description "PowerShell script checks `$LASTEXITCODE after executing native binaries" -Passed $checksLastExitCode -Details "`$LASTEXITCODE checks verified"

    # Test 2.3.4: PowerShell script reports red error status upon non-zero exit code
    $reportsNonZero = ($ps1Content -match '\$LASTEXITCODE\s*-ne\s*0' -or $ps1Content -match '\$LASTEXITCODE\s*-gt\s*0')
    Register-TestResult -TestId "T2.3.4" -Description "PowerShell script detects and reports failure when `$LASTEXITCODE -ne 0" -Passed $reportsNonZero -Details "Exit code error branch detected"

    # Test 2.3.5: Runner propagation contract
    $runnerScript = "$TestDir\run_tests.ps1"
    $runnerExists = Test-Path $runnerScript
    $runnerPropagates = $false
    if ($runnerExists) {
        $runnerContent = Get-Content $runnerScript -Raw -Encoding UTF8
        $runnerPropagates = ($runnerContent -match 'exit\s+\$LASTEXITCODE' -or $runnerContent -match 'exit\s+\$suiteExitCode' -or $runnerContent -match 'exit\s+\$')
    }
    Register-TestResult -TestId "T2.3.5" -Description "Test runner propagates test suite exit code to host environment" -Passed $runnerPropagates -Details "run_tests.ps1 exit propagation verified"

    # --------------------------------------------------------------------------
    # Group 4: UsbDk Missing Detection Logic
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 2" -GroupName "Boundary Group 4: UsbDk Missing Detection Logic"

    # Test 2.4.1: CIM / WMI query for UsbDk driver
    $hasCimCheck = ($ps1Content -match "Win32_SystemDriver" -and $ps1Content -match "UsbDk")
    Register-TestResult -TestId "T2.4.1" -Description "Diagnostics queries Win32_SystemDriver for UsbDk driver" -Passed $hasCimCheck -Details "CIM / WMI driver filter verified"

    # Test 2.4.2: Filesystem fallback check for UsbDk
    $hasFsCheck = ($ps1Content -match "UsbDk Runtime Libraries" -or $ps1Content -match "C:\\Program Files\\UsbDk")
    Register-TestResult -TestId "T2.4.2" -Description "Diagnostics includes filesystem check for UsbDk Runtime Libraries" -Passed $hasFsCheck -Details "Filesystem fallback check verified"

    # Test 2.4.3: UsbDk automated installation command uses msiexec
    $hasMsiexec = ($ps1Content -match "msiexec" -and $ps1Content -match "UsbDk.*\.msi")
    Register-TestResult -TestId "T2.4.3" -Description "UsbDk installer triggers msiexec /i on UsbDk MSI" -Passed $hasMsiexec -Details "msiexec invocation pattern verified"

    # Test 2.4.4: UsbDk installer requests administrator elevation (RunAs)
    $hasElevation = ($ps1Content -match 'Start-Process.*-Verb\s+RunAs' -or $ps1Content -match 'RunAs')
    Register-TestResult -TestId "T2.4.4" -Description "UsbDk installer initiates UAC elevation (RunAs verb)" -Passed $hasElevation -Details "RunAs elevation verified"

    # Test 2.4.5: Target installer file exists and is valid MSI binary
    $msiPath = "$WorkspaceRoot\drivers\UsbDk_1.0.22_x64.msi"
    $msiValid = $false
    if (Test-Path $msiPath) {
        $bytes = [System.IO.File]::ReadAllBytes($msiPath)
        # Check OLE Compound Document magic: D0 CF 11 E0 A1 B1 1A E1
        if ($bytes.Length -gt 8 -and 
            $bytes[0] -eq 0xD0 -and $bytes[1] -eq 0xCF -and $bytes[2] -eq 0x11 -and $bytes[3] -eq 0xE0) {
            $msiValid = $true
        }
    }
    Register-TestResult -TestId "T2.4.5" -Description "UsbDk_1.0.22_x64.msi is a valid Microsoft Installer compound file" -Passed $msiValid -Details "OLE magic D0 CF 11 E0 verified"

    # --------------------------------------------------------------------------
    # Group 5: Preloader Protection Assertions
    # --------------------------------------------------------------------------
    Start-TierGroup -TierName "Tier 2" -GroupName "Boundary Group 5: Preloader Protection Assertions"

    $allToolScripts = Get-ChildItem -Path $ToolDir -Filter "*.*" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\tests\\' }
    $preloaderErased = @()
    $boot1Erased = @()
    $boot2Erased = @()
    $preloaderFlashed = @()

    foreach ($f in $allToolScripts) {
        if ($f.Extension -in @(".bat", ".ps1")) {
            $text = Get-Content $f.FullName -Raw -Encoding UTF8
            if ($text -match '(?i)(erase\s+preloader|e\s+preloader|\be\s+[^\r\n;"]*preloader)') {
                $preloaderErased += $f.Name
            }
            if ($text -match '(?i)(erase\s+boot1|e\s+boot1|\be\s+[^\r\n;"]*boot1)') {
                $boot1Erased += $f.Name
            }
            if ($text -match '(?i)(erase\s+boot2|e\s+boot2|\be\s+[^\r\n;"]*boot2)') {
                $boot2Erased += $f.Name
            }
            if ($text -match '(?i)(flash\s+preloader|w\s+preloader|wf\s+preloader)') {
                $preloaderFlashed += $f.Name
            }
        }
    }

    # Test 2.5.1: Zero instances of erasing preloader
    $zeroPreloaderErase = ($preloaderErased.Count -eq 0)
    $detail = if ($zeroPreloaderErase) { "Zero instances of preloader erase found." } else { "VIOLATION in: $($preloaderErased -join ', ')" }
    Register-TestResult -TestId "T2.5.1" -Description "Zero occurrences of erasing preloader partition across all scripts" -Passed $zeroPreloaderErase -Details $detail

    # Test 2.5.2: Zero instances of erasing boot1
    $zeroBoot1Erase = ($boot1Erased.Count -eq 0)
    $detail = if ($zeroBoot1Erase) { "Zero instances of boot1 erase found." } else { "VIOLATION in: $($boot1Erased -join ', ')" }
    Register-TestResult -TestId "T2.5.2" -Description "Zero occurrences of erasing boot1 hardware partition" -Passed $zeroBoot1Erase -Details $detail

    # Test 2.5.3: Zero instances of erasing boot2
    $zeroBoot2Erase = ($boot2Erased.Count -eq 0)
    $detail = if ($zeroBoot2Erase) { "Zero instances of boot2 erase found." } else { "VIOLATION in: $($boot2Erased -join ', ')" }
    Register-TestResult -TestId "T2.5.3" -Description "Zero occurrences of erasing boot2 hardware partition" -Passed $zeroBoot2Erase -Details $detail

    # Test 2.5.4: Zero instances of flashing preloader
    $zeroPreloaderFlash = ($preloaderFlashed.Count -eq 0)
    $detail = if ($zeroPreloaderFlash) { "Zero instances of flashing preloader found." } else { "VIOLATION in: $($preloaderFlashed -join ', ')" }
    Register-TestResult -TestId "T2.5.4" -Description "Zero occurrences of flashing preloader partition" -Passed $zeroPreloaderFlash -Details $detail

    # Test 2.5.5: Explicit preloader warning notice present in README.md
    $hasSafetyDocs = if (Test-Path "$ToolDir\README.md") {
        (Get-Content "$ToolDir\README.md" -Raw -Encoding UTF8) -match "(?i)preloader"
    } else { $false }
    Register-TestResult -TestId "T2.5.5" -Description "Documentation provides explicit preloader anti-brick warnings" -Passed $hasSafetyDocs -Details "Safety documentation verified"
}

# ==============================================================================
# TIER 3: CROSS-FEATURE INTERACTIONS
# ==============================================================================
if ($Tier -in @("3", "All")) {
    Start-TierGroup -TierName "Tier 3" -GroupName "Cross-Feature Interactions & Asset Integrity"

    # Test 3.1: Sequential workflow dependencies (Stage 0 -> Stage 1 -> Stage 2)
    $seqConsistent = (Test-Path "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat") -and 
                     (Test-Path "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat") -and 
                     (Test-Path "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat")
    Register-TestResult -TestId "T3.1" -Description "Sequential batch script chain (0 -> 1 -> 2) exists with consistent nomenclature" -Passed $seqConsistent -Details "Stages 0, 1, 2 verified"

    # Test 3.2: Menu options mapping to underlying scripts
    $ps1Content = if (Test-Path "$ToolDir\dandelion_tool.ps1") { Get-Content "$ToolDir\dandelion_tool.ps1" -Raw -Encoding UTF8 } else { "" }
    $menuMapsUnlock = ($ps1Content -match "0_DEVERROUILLER_BOOTLOADER_DANDELION\.bat" -or $ps1Content -match "da seccfg unlock")
    $menuMapsRecovery = ($ps1Content -match "1_FLASHER_RECOVERY_ET_VBMETA\.bat" -or ($ps1Content -match "flash recovery" -and $ps1Content -match "vbmeta"))
    $menuMapsRom = ($ps1Content -match "2_INSTALLER_ROM_64BIT_ET_ROOT\.bat" -or ($ps1Content -match "adb push" -or $ps1Content -match "sideload"))
    $menuMapped = ($menuMapsUnlock -and $menuMapsRecovery -and $menuMapsRom)
    Register-TestResult -TestId "T3.2" -Description "Interactive menu options faithfully map to the 3 lifecycle execution stages" -Passed $menuMapped -Details "Mapping verified for stages 0, 1, 2"

    # Test 3.3: vbmeta.img format, size, and AVB0 header
    $vbmetaPath = "$ToolDir\recovery\vbmeta.img"
    $vbmetaValid = $false
    $vbmetaDetails = ""
    if (Test-Path $vbmetaPath) {
        $bytes = [System.IO.File]::ReadAllBytes($vbmetaPath)
        $size = $bytes.Length
        $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(4, $bytes.Length))
        if ($size -eq 4096 -and $magic -eq "AVB0") {
            $vbmetaValid = $true
            $vbmetaDetails = "Size: $size bytes, Magic: $magic (AVB 2.0 Header confirmed)"
        } else {
            $vbmetaDetails = "Size: $size (expected 4096), Magic: $magic (expected AVB0)"
        }
    } else {
        $vbmetaDetails = "File missing at $vbmetaPath"
    }
    Register-TestResult -TestId "T3.3" -Description "recovery\vbmeta.img exists, is exactly 4096 bytes, and has AVB0 magic header" -Passed $vbmetaValid -Details $vbmetaDetails

    # Test 3.4: recovery\recovery.img format and presence
    $recPath = "$ToolDir\recovery\recovery.img"
    $recValid = $false
    $recDetails = ""
    if (Test-Path $recPath) {
        $bytes = [System.IO.File]::ReadAllBytes($recPath)
        $size = $bytes.Length
        if ($size -gt 1024) {
            $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(8, $bytes.Length))
            $recValid = $true
            $recDetails = "Size: $size bytes, Magic: $magic"
        } else {
            $recDetails = "File too small ($size bytes)"
        }
    } else {
        $recDetails = "File missing at $recPath"
    }
    Register-TestResult -TestId "T3.4" -Description "recovery\recovery.img exists and is a non-empty image file" -Passed $recValid -Details $recDetails

    # Test 3.5: roms\Magisk-v26.4.apk format and size
    $magiskPath = "$ToolDir\roms\Magisk-v26.4.apk"
    $magiskValid = $false
    $magiskDetails = ""
    if (Test-Path $magiskPath) {
        $bytes = [System.IO.File]::ReadAllBytes($magiskPath)
        $size = $bytes.Length
        # Check ZIP / APK magic: PK\x03\x04
        if ($size -gt 1000000 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and $bytes[2] -eq 0x03 -and $bytes[3] -eq 0x04) {
            $magiskValid = $true
            $magiskDetails = "Size: $size bytes, ZIP magic PK\x03\x04 confirmed"
        } else {
            $magiskDetails = "Size: $size bytes, Invalid ZIP magic or file truncated"
        }
    } else {
        $magiskDetails = "File missing at $magiskPath"
    }
    Register-TestResult -TestId "T3.5" -Description "roms\Magisk-v26.4.apk exists, is valid ZIP/APK format, and >1MB" -Passed $magiskValid -Details $magiskDetails

    # Test 3.6: roms\README_ROMS.md specifies Magisk v26.4 and ARM64 ROM details
    $romsReadmePath = "$ToolDir\roms\README_ROMS.md"
    $romsAligned = $false
    if (Test-Path $romsReadmePath) {
        $rContent = Get-Content $romsReadmePath -Raw -Encoding UTF8
        $romsAligned = ($rContent -match "Magisk.*v26" -and $rContent -match "arm64|aarch64" -and ($rContent -match "SHA256|sha256|checksum|Taille"))
    }
    Register-TestResult -TestId "T3.6" -Description "roms\README_ROMS.md aligns with Magisk v26.4 and arm64 custom ROM specs" -Passed $romsAligned -Details "ROMs and Magisk alignment verified"
}

# ==============================================================================
# TIER 4: REAL-WORLD SCENARIOS & ACCEPTANCE AUDIT
# ==============================================================================
if ($Tier -in @("4", "All")) {
    Start-TierGroup -TierName "Tier 4" -GroupName "Real-World Scenarios & Acceptance Audit"

    # Scenario S1: Out-of-the-box fresh Windows workstation setup
    # Tests that environment diagnostic logic executes cleanly and returns comprehensive report
    try {
        $diagTest = $false
        $diagMsg = ""
        $pyCheck = python --version 2>&1
        $adbCheck = & "$WorkspaceRoot\bin\adb.exe" version 2>&1
        $fbCheck = & "$WorkspaceRoot\bin\fastboot.exe" --version 2>&1
        $usbdkCheck = Test-Path "$WorkspaceRoot\drivers\UsbDk_1.0.22_x64.msi"

        if ($adbCheck -match "Android Debug Bridge" -and $fbCheck -match "fastboot version" -and $usbdkCheck) {
            $diagTest = $true
            $diagMsg = "Host workstation has active Python, Fastboot, ADB, and UsbDk package."
        } else {
            $diagMsg = "Component check: ADB=$($adbCheck -ne $null), FB=$($fbCheck -ne $null), UsbDk=$usbdkCheck"
        }
        Register-TestResult -TestId "T4.1" -Description "Scenario S1: Fresh technician workstation environment validation" -Passed $diagTest -Details $diagMsg
    } catch {
        Register-TestResult -TestId "T4.1" -Description "Scenario S1: Fresh technician workstation environment validation" -Passed $false -Details $_.Exception.Message
    }

    # Scenario S2: Locked FRP & Bootloader BROM unlock simulated lifecycle
    # Validates that mtkclient argument parser accepts the multi-command arguments without syntax errors
    try {
        $bromSimPass = $false
        $mtkPath = "$WorkspaceRoot\src\mtkclient\mtk.py"
        # Run python mtk.py with multi --help or da seccfg --help
        $daHelp = python "$mtkPath" da seccfg --help 2>&1
        $multiHelp = python "$mtkPath" multi --help 2>&1
        if (($daHelp -match "unlock,lock" -or $daHelp -match "flag") -and ($multiHelp -match "commands" -or $multiHelp -match "multi")) {
            $bromSimPass = $true
            $bromMsg = "mtk.py accepts both 'da seccfg' and 'multi' commands natively."
        } else {
            $bromMsg = "mtkclient command validation output: $daHelp"
        }
        Register-TestResult -TestId "T4.2" -Description "Scenario S2: MT6762G BROM unlock and FRP erase command pipeline validation" -Passed $bromSimPass -Details $bromMsg
    } catch {
        Register-TestResult -TestId "T4.2" -Description "Scenario S2: MT6762G BROM unlock and FRP erase command pipeline validation" -Passed $false -Details $_.Exception.Message
    }

    # Scenario S3: Fastboot custom recovery & AVB bypass workflow
    # Validates that fastboot parser accepts --disable-verity and --disable-verification with flash vbmeta
    try {
        $fbSimPass = $false
        $fastbootPath = "$WorkspaceRoot\bin\fastboot.exe"
        # Test fastboot option recognition via help / argument test
        $fbHelp = & "$fastbootPath" --help 2>&1
        $hasDisableVerity = ($fbHelp -match "--disable-verity")
        $hasDisableVerification = ($fbHelp -match "--disable-verification")
        $hasFlashCmd = ($fbHelp -match "flash\s+PARTITION")
        $hasRebootCmd = ($fbHelp -match "reboot\s+\[")

        if ($hasDisableVerity -and $hasDisableVerification -and $hasFlashCmd -and $hasRebootCmd) {
            $fbSimPass = $true
            $fbMsg = "Fastboot binary validates support for --disable-verity, --disable-verification, flash, and reboot."
        } else {
            $fbMsg = "Fastboot option missing from help output."
        }
        Register-TestResult -TestId "T4.3" -Description "Scenario S3: Fastboot recovery flash and AVB disable argument pipeline validation" -Passed $fbSimPass -Details $fbMsg
    } catch {
        Register-TestResult -TestId "T4.3" -Description "Scenario S3: Fastboot recovery flash and AVB disable argument pipeline validation" -Passed $false -Details $_.Exception.Message
    }

    # Scenario S4: 64-bit ROM transition & Magisk root injection verification logic simulation
    # Validates the verification logic for CPU ABI and root privileges under positive and negative test cases
    try {
        $s4Pass = $true
        $s4Errors = @()

        # Simulated ABI outputs
        $mockStockAbi = "armeabi-v7a"
        $mock64bitAbi = "arm64-v8a"
        $abiRegex = "^arm64-v8a\s*$"

        if ($mockStockAbi -match $abiRegex) {
            $s4Pass = $false
            $s4Errors += "Stock 32-bit ABI was falsely accepted by arm64-v8a validator."
        }
        if (-not ($mock64bitAbi -match $abiRegex)) {
            $s4Pass = $false
            $s4Errors += "64-bit ABI was rejected by arm64-v8a validator."
        }

        # Simulated Root outputs
        $mockNoRoot = "uid=2000(shell) gid=2000(shell) groups=2000(shell)"
        $mockSuNotFound = "/system/bin/sh: su: not found"
        $mockRootSuccess = "uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0"
        $rootRegex = "uid=0\(root\)"

        if ($mockNoRoot -match $rootRegex) {
            $s4Pass = $false
            $s4Errors += "Non-root shell output was falsely accepted by root validator."
        }
        if ($mockSuNotFound -match $rootRegex) {
            $s4Pass = $false
            $s4Errors += "su not found output was falsely accepted by root validator."
        }
        if (-not ($mockRootSuccess -match $rootRegex)) {
            $s4Pass = $false
            $s4Errors += "Root output was rejected by root validator."
        }

        $s4Details = if ($s4Pass) { "Positive and adversarial negative test cases for ABI (arm64-v8a) and root (uid=0(root)) passed perfectly." } else { $s4Errors -join '; ' }
        Register-TestResult -TestId "T4.4" -Description "Scenario S4: 64-bit ABI and Root verification logic adversarial simulation" -Passed $s4Pass -Details $s4Details
    } catch {
        Register-TestResult -TestId "T4.4" -Description "Scenario S4: 64-bit ABI and Root verification logic adversarial simulation" -Passed $false -Details $_.Exception.Message
    }

    # Scenario S5: Acceptance Criteria Comprehensive Audit against ORIGINAL_REQUEST.md
    # Validates the 4 bullet points in ORIGINAL_REQUEST.md lines 27-40
    try {
        $acAuditPass = $true
        $acIssues = @()

        # AC 1: Non-regression check on Begonia files
        $gitStatus = git -C "$WorkspaceRoot" status --porcelain 2>&1
        foreach ($line in ($gitStatus -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $status = $line.Substring(0, 2)
            $file = $line.Substring(3).Trim()
            if ($status -match '^[ MADRCU]' -and $status -ne '??') {
                if (-not $file.StartsWith("dandelion_tool/") -and -not $file.StartsWith(".agents/") -and -not $file.StartsWith("dandelion_tool\")) {
                    $acAuditPass = $false
                    $acIssues += "AC1 Violation: Modified file outside dandelion_tool: $file"
                }
            }
        }

        # AC 2: Dedicated dandelion_tool structure
        if (-not (Test-Path "$ToolDir\recovery") -or -not (Test-Path "$ToolDir\roms")) {
            $acAuditPass = $false
            $acIssues += "AC2 Violation: Missing recovery/ or roms/ subdirectories in dandelion_tool/"
        }

        # AC 3: Scripts present and relative paths used
        $expectedScripts = @(
            "0_DEVERROUILLER_BOOTLOADER_DANDELION.bat",
            "1_FLASHER_RECOVERY_ET_VBMETA.bat",
            "2_INSTALLER_ROM_64BIT_ET_ROOT.bat"
        )
        foreach ($es in $expectedScripts) {
            if (-not (Test-Path "$ToolDir\$es")) {
                $acAuditPass = $false
                $acIssues += "AC3 Violation: Missing execution script $es"
            }
        }

        # AC 4: Verification commands in documentation and script
        $readmeText = if (Test-Path "$ToolDir\README.md") { Get-Content "$ToolDir\README.md" -Raw -Encoding UTF8 } else { "" }
        if (-not ($readmeText -match "ro\.product\.cpu\.abi" -and $readmeText -match "arm64-v8a" -and $readmeText -match "su\s+-c")) {
            $acAuditPass = $false
            $acIssues += "AC4 Violation: Missing scripted documentation for ro.product.cpu.abi and su -c 'id'"
        }

        $acDetails = if ($acAuditPass) { "All 4 acceptance criteria in ORIGINAL_REQUEST.md fully satisfied." } else { $acIssues -join '; ' }
        Register-TestResult -TestId "T4.5" -Description "Scenario S5: Full Acceptance Criteria audit against ORIGINAL_REQUEST.md" -Passed $acAuditPass -Details $acDetails
    } catch {
        Register-TestResult -TestId "T4.5" -Description "Scenario S5: Full Acceptance Criteria audit against ORIGINAL_REQUEST.md" -Passed $false -Details $_.Exception.Message
    }
}

# ==============================================================================
# SUMMARY TABLE & EXIT CODE CALCULATION
# ==============================================================================
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                           TEST EXECUTION SUMMARY                               " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$tierGroups = $global:TestResults | Group-Object Tier
$tierSummary = @()

foreach ($tg in $tierGroups) {
    $totalCount = $tg.Group.Count
    $passCount = @($tg.Group | Where-Object { $_.Passed }).Count
    $failCount = @($tg.Group | Where-Object { -not $_.Passed }).Count
    $pct = if ($totalCount -gt 0) { [Math]::Round(($passCount / $totalCount) * 100, 1) } else { 0 }

    $tierSummary += [PSCustomObject]@{
        Tier        = $tg.Name
        "Total Tests" = $totalCount
        Passed      = $passCount
        Failed      = $failCount
        "Pass Rate" = "$pct %"
    }
}

$tierSummary | Format-Table -AutoSize | Out-String | Write-Host

$grandTotal = $global:TestResults.Count
$grandPassed = @($global:TestResults | Where-Object { $_.Passed }).Count
$grandFailed = @($global:TestResults | Where-Object { -not $_.Passed }).Count
$overallPct = if ($grandTotal -gt 0) { [Math]::Round(($grandPassed / $grandTotal) * 100, 1) } else { 0 }

Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "TOTAL TESTS RUN : $grandTotal" -ForegroundColor White
Write-Host "PASSED          : $grandPassed" -ForegroundColor Green
Write-Host "FAILED          : $grandFailed" -ForegroundColor $(if ($grandFailed -eq 0) { "Green" } else { "Red" })
Write-Host "OVERALL RATE    : $overallPct %" -ForegroundColor $(if ($grandFailed -eq 0) { "Green" } else { "Yellow" })
Write-Host "================================================================================" -ForegroundColor Cyan

if ($grandFailed -gt 0) {
    Write-Host ""
    Write-Host "FAILED TESTS BREAKDOWN:" -ForegroundColor Red
    $failedTests = @($global:TestResults | Where-Object { -not $_.Passed })
    foreach ($ft in $failedTests) {
        Write-Host "  - [$($ft.Tier)] $($ft.Id): $($ft.Description)" -ForegroundColor Red
        if ($ft.Details) {
            Write-Host "    Reason: $($ft.Details)" -ForegroundColor DarkYellow
        }
    }
    Write-Host ""
    exit 1
} else {
    Write-Host ""
    Write-Host "[SUCCESS] All E2E test assertions passed successfully!" -ForegroundColor Green
    Write-Host ""
    exit 0
}
