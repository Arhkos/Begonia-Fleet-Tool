# Handoff Report: Begonia Workspace Survey & Standards Extraction for `dandelion_tool`

**Agent ID**: `explorer_survey_1`  
**Timestamp**: 2026-09-30T21:16:00Z  
**Target Module**: `dandelion_tool/`  
**Reference Original Request**: `.agents/teamwork/ORIGINAL_REQUEST.md`

---

## 1. Observation

Direct investigation of the repository layout, executable scripts, and configuration files revealed the following exact facts and behaviors:

### 1.1 Root Directory Layout & Script Inventory
Inspection of `c:\Users\Arhkos\Documents\antigravity\peaceful-babbage` identified:
- **Root Scripts**:
  - `MENU_GENERAL.bat` (4 lines, 100 bytes): Wrapper calling PowerShell.
  - `0_INSTALLER_PILOTE_USBDK.bat` (24 lines, 1027 bytes): UsbDk driver installer with UAC elevation.
  - `1_DEVERROUILLER_BOOTLOADER_ET_FRP.bat` (22 lines, 1135 bytes): BootROM bootloader unlock & FRP bypass via mtkclient.
  - `2_RESTAURER_STOCK_EEA_UNBRICK.bat` (29 lines, 1515 bytes): 29-partition unbrick/restore runner via `src\flash_stock_complete.py`.
  - `3_FLASHER_RECOVERY_ET_VBMETA.bat` (25 lines, 1126 bytes): Fastboot recovery & vbmeta flashing script.
  - `4_ENVOYER_ROM_SUR_TELEPHONE.bat` (37 lines, 1914 bytes): ADB push script for ROM and firmware packages with TWRP MTP re-initialization guidance.
  - `begonia_tool.ps1` (244 lines, 13340 bytes): Full interactive terminal menu with environment diagnostic and error handling.
- **Root Subdirectories**:
  - `bin/`: Platform tools (`adb.exe` v1.0.41, `fastboot.exe` v31.0.2, `AdbWinApi.dll`, `AdbWinUsbApi.dll`, `libwinpthread-1.dll`, `make_f2fs.exe`, `mke2fs.exe`, `sqlite3.exe`).
  - `drivers/`: `UsbDk_1.0.22_x64.msi` (6.34 MB) and `android_fastboot.inf`.
  - `recovery/`: Device-specific images (`BRPv3.6.img`, `recovery.img`, `vbmeta.img`).
  - `roms/`: Device-specific zip archives (`FW R-OSS + BRP 3.1 - Begonia.zip`, `PixelExperience_Plus_begonia-13.0-20231217-1732-OFFICIAL.zip`).
  - `stock_firmware/`: Subdirectory `images/` holding factory stock partitions.
  - `src/`: Contains `flash_stock_complete.py` and full clone/submodule `mtkclient/`.
  - `OLD/`: Deprecated / historical scripts and logs.

### 1.2 Menu Formatting, Ergonomics & User Prompts
Analysis of `MENU_GENERAL.bat` and `begonia_tool.ps1`:
- **CMD Bootstrap pattern** (`MENU_GENERAL.bat:1-3`):
  ```cmd
  @echo off
  cd /d "%~dp0"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0begonia_tool.ps1"
  ```
- **Batch Script Anatomy** (from `1_DEVERROUILLER_BOOTLOADER_ET_FRP.bat:1-21` and `3_FLASHER_RECOVERY_ET_VBMETA.bat:1-24`):
  - Line 1: `@echo off`
  - Line 2: `chcp 65001 >nul` (sets console code page to UTF-8 to prevent character corruption).
  - Line 3: `title <Number>. <TITLE_IN_CAPS>`
  - Section Header:
    ```cmd
    echo =====================================================================
    echo    ETAPE X : INTITULE
    echo =====================================================================
    echo.
    ```
  - Instruction block: Numbered steps detailing hardware button interactions (`[VOLUME HAUT] + [VOLUME BAS]`, etc.).
  - Action notification: `echo Lancement de la sequence ...`
  - Execution command with double quotes: `python "%~dp0..."` or `"%~dp0bin\fastboot.exe" ...`
  - Completion banner:
    ```cmd
    echo =====================================================================
    echo    OPERATION TERMINEE ! ...
    echo =====================================================================
    pause
    ```
  - Trailing `pause` prevents the CMD window from disappearing when double-clicked from Windows Explorer.
- **PowerShell Interactive Menu Anatomy** (`begonia_tool.ps1:14-243`):
  - Visual Theme:
    - Cyan borders: `Write-Host "=================================================================" -ForegroundColor Cyan`
    - Yellow titles: `Write-Host "   BEGONIA FLEET MANAGER ... " -ForegroundColor Yellow`
    - DarkGray section headers: `Write-Host "--- SECTION ---" -ForegroundColor DarkGray`
    - Status tags:
      - `[+]` in `Green` for success / detected.
      - `[-]` in `Red` for missing / error.
      - `[*]` in `Yellow` for in-progress operations.
      - `[!]` in `Cyan` for critical user guidance (e.g. UAC prompt or button pressing instructions).
  - Diagnostic Routine (`Check-Environment`):
    - Checks UsbDk via CIM (`Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'"`), Registry, and filesystem paths (`C:\Program Files\UsbDk Runtime Library`).
    - Checks Python via `python --version 2>&1`.
    - Checks local binaries and target files via `Test-Path "$ScriptDir\bin\fastboot.exe"`, etc.
  - User Flow & Confirmation:
    - Detailed multi-step instructions displayed before execution.
    - Explicit confirmation prompt: `Read-Host "Appuyez sur Entree quand pret..."`
    - Interactive loop: `do { Show-Menu ... switch ($choice) { ... } } while ($choice -ne "6")`
    - Invalid input handling: `Default { Write-Host "Option invalide." -ForegroundColor Red; Start-Sleep -Seconds 1 }`

### 1.3 Path Handling, Spaces, Quotes & Privilege Checks
- **Path Resolution**:
  - Batch scripts use `%~dp0` to obtain the directory of the running script. Note that `%~dp0` includes a trailing backslash.
  - PowerShell uses `$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path`.
  - All paths are systematically enclosed in double quotes (e.g., `"%~dp0bin\fastboot.exe"`, `"$ScriptDir\bin\fastboot.exe"`), which completely avoids breakage when project paths contain spaces (e.g., `FW R-OSS + BRP 3.1 - Begonia.zip`).
- **Exit Code Checking**:
  - In batch: `if %errorlevel% neq 0 (...)`
  - In PowerShell: `$LASTEXITCODE` is verified after native commands (`& "$fastbootExe" ...`, `if ($LASTEXITCODE -ne 0) { Write-Host "[-] ERREUR : ... (code $LASTEXITCODE)." -ForegroundColor Red; return }`).
- **Administrator Elevation**:
  - In `0_INSTALLER_PILOTE_USBDK.bat:11-18`:
    ```cmd
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo [*] Elevation des privileges Administrateur en cours (UAC)...
        powershell -Command "Start-Process msiexec.exe -ArgumentList '/i', '\"%~dp0drivers\UsbDk_1.0.22_x64.msi\"' -Verb RunAs -Wait"
    ) else (
        msiexec /i "%~dp0drivers\UsbDk_1.0.22_x64.msi"
    )
    ```
  - In PowerShell (`begonia_tool.ps1:82`):
    `Start-Process msiexec.exe -ArgumentList "/i", "`"$msiPath`"" -Verb RunAs -Wait`

### 1.4 Binary Invocations & Submodule Integration
- `bin/fastboot.exe` and `bin/adb.exe`:
  - Directly executable platform-tools binaries compiled for Windows x64.
  - Tested: `bin\fastboot.exe --version` returned `31.0.2-7242960` (exit code 0).
  - Tested: `bin\adb.exe version` returned `Android Debug Bridge version 1.0.41 (31.0.2-7242960)` (exit code 0).
- `src/mtkclient`:
  - Contains full `bkerler/mtkclient` v2.1.4.
  - Tested: `python src\mtkclient\mtk.py --help` returned exit code 0 under Python 3.11.15.
  - Verified chip configuration in `src/mtkclient/mtkclient/config/brom_config.py:1381-1383`:
    - `name="MT6761/MT6762/MT3369/MT8766B/MT8761/AC8259/AC8257"`
    - `description="Helio A20/P22/A22/A25/G25"`
    - `dacode=0x6761`
    - `loader="mt6761_payload.bin"`
  - Tested relative execution from subdirectories: `python ..\..\..\src\mtkclient\mtk.py --help` succeeds without error.
  - Driver: `drivers/UsbDk_1.0.22_x64.msi` is compatible with all MediaTek SoCs (MT6785 for Begonia, MT6762G for Dandelion) without modifying host filter drivers.

### 1.5 Git Status & Non-Regression Baseline
- `git status` check:
  - Branch: `master` up to date with `origin/master`.
  - No modified files.
  - Untracked files currently: only `.agents/`, `hwparam.json`, and `src/mtkclient/`.
  - Zero modifications exist on any tracked project files.

---

## 2. Logic Chain

1. **Isolation & Modularity (`R1`)**:
   - *Observation*: The root directory contains standalone batch files and a PowerShell tool specialized for Begonia (`begonia_tool.ps1`, `2_RESTAURER_STOCK_EEA_UNBRICK.bat`, `recovery/`, `roms/`).
   - *Deduction*: Any modification to existing root batch files, root documentation, or Begonia asset directories (`recovery/`, `roms/`, `stock_firmware/`) would violate strict non-regression (`R1` and Acceptance Criteria line 30).
   - *Actionable Requirement*: All assets, menus, and scripts for Dandelion must reside strictly inside `dandelion_tool/`.

2. **Binary Reuse via Relative Paths (`R1`)**:
   - *Observation*: `bin/adb.exe`, `bin/fastboot.exe`, `drivers/UsbDk_1.0.22_x64.msi`, and `src/mtkclient/mtk.py` are present at the project root level. Relative calls from subfolders succeed (`python ..\src\mtkclient\mtk.py`).
   - *Deduction*: Placing duplicate binaries in `dandelion_tool/` would bloat the repository and break maintainability.
   - *Actionable Requirement*: Scripts inside `dandelion_tool/` must access shared resources via `..\bin\adb.exe`, `..\bin\fastboot.exe`, `..\drivers\UsbDk_1.0.22_x64.msi`, and `..\src\mtkclient\mtk.py`.
   - *Path Formula for CMD*: `"%~dp0..\bin\fastboot.exe"`, `"%~dp0..\bin\adb.exe"`, `python "%~dp0..\src\mtkclient\mtk.py"`.
   - *Path Formula for PowerShell*: `$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path; $WorkspaceRoot = Split-Path -Parent $ToolDir; $Fastboot = "$WorkspaceRoot\bin\fastboot.exe"`, etc.

3. **BootROM Exploit & Bootloader Unlock (`R2`)**:
   - *Observation*: `brom_config.py` confirms native MT6762 support (`dacode=0x6761`, `mt6761_payload.bin`). The Begonia unlock script executes:
     `python "%~dp0src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`
   - *Deduction*: The MT6762G (Helio G25) uses the exact same BROM command pipeline: `da seccfg unlock` overrides the secure boot configuration partition (`seccfg`), `e frp` erases Google Factory Reset Protection, and `reset` initiates device reboot.
   - *Actionable Requirement*: `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat` must invoke `python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`.
   - *Hardware Key Interaction*: On Redmi 10A (dandelion), entering BROM requires holding `[VOLUME HAUT] + [VOLUME BAS]` (or `[VOLUME BAS]` depending on board revision) on an unpowered phone while inserting the USB cable.

4. **Recovery Flash & AVB Disable (`R3`)**:
   - *Observation*: In `3_FLASHER_RECOVERY_ET_VBMETA.bat`, Fastboot flashes `vbmeta` with `--disable-verity --disable-verification` before flashing recovery.
   - *Deduction*: MT6762 devices enforce Android Verified Boot 2.0 (AVB). Flashing a custom recovery without disabling verity in `vbmeta` causes a bootloop or DM-verity corruption screen.
   - *Actionable Requirement*: `1_FLASHER_RECOVERY_ET_VBMETA.bat` must execute:
     - `"%~dp0..\bin\fastboot.exe" flash vbmeta "%~dp0recovery\vbmeta.img" --disable-verity --disable-verification`
     - `"%~dp0..\bin\fastboot.exe" flash recovery "%~dp0recovery\recovery.img"`
     - `"%~dp0..\bin\fastboot.exe" reboot recovery`
   - *Safety Rule*: Never flash or overwrite the `preloader` partition during custom recovery operations.

5. **64-bit Architecture & Root Integration (`R4`, `R5`)**:
   - *Observation*: Stock Redmi 10A MIUI runs in 32-bit user mode (`armeabi-v7a`) despite having an 8-core 64-bit Cortex-A53 CPU.
   - *Deduction*: Installing a 64-bit unified Blossom/Dandelion ROM (such as LineageOS 20 arm64 or crDroid 9 arm64) transitions the device to `arm64-v8a`. Root injection via Magisk v26+ or KernelSU requires testing both architecture and root privileges via ADB.
   - *Actionable Requirement*: `2_INSTALLER_ROM_64BIT_ET_ROOT.bat` and PowerShell must push the 64-bit ROM package and root components, followed by scripted ADB checks:
     - Architecture check: `"%~dp0..\bin\adb.exe" shell getprop ro.product.cpu.abi` (must return `arm64-v8a`).
     - Root check: `"%~dp0..\bin\adb.exe" shell su -c "id"` (must return `uid=0(root)`).

6. **Ergonomic Continuity (`R5`)**:
   - *Observation*: Technicians working with Begonia Fleet Tool expect consistent aesthetics, colored text tags, diagnostic checklists, interactive menus, and clear instructions.
   - *Deduction*: `dandelion_tool/` must offer both standalone 1-click batch scripts (`0_...`, `1_...`, `2_...`) and an interactive menu (`MENU_DANDELION.bat` calling `dandelion_tool.ps1`).

---

## 3. Caveats

1. **USB Port Quality**: MediaTek BROM handshake can be sensitive to USB 3.0/3.1 controllers or USB hubs. USB 2.0 direct motherboard ports are strongly recommended.
2. **UsbDk Coexistence**: UsbDk operates in user-space and does not overwrite WinUSB drivers, but on systems with conflicting legacy `libusb0.sys` filter drivers, a reboot may be necessary.
3. **Partition Preloader Protection**: The `preloader` partition on MT6762 must never be modified or overwritten with incorrect binaries; our scripts explicitly avoid touching `preloader`.
4. **Hardware Revisions**: Redmi 10A models exist in 2GB and 3GB RAM variants. The 64-bit ROM selection must support both configurations smoothly without zram exhaustion.

---

## 4. Conclusion & Recommended Architecture for `dandelion_tool/`

The new module `dandelion_tool/` can be created in complete isolation adhering to the Begonia ergonomic and execution standards:

### Proposed Directory Layout
```
dandelion_tool/
├── MENU_DANDELION.bat                      # 1-clic wrapper -> dandelion_tool.ps1
├── dandelion_tool.ps1                      # Complete PowerShell Fleet Manager for Dandelion
├── 0_DEVERROUILLER_BOOTLOADER_DANDELION.bat # Standalone BROM unlock & FRP wipe
├── 1_FLASHER_RECOVERY_ET_VBMETA.bat        # Standalone Fastboot recovery & vbmeta flash
├── 2_INSTALLER_ROM_64BIT_ET_ROOT.bat       # Standalone ADB push ROM & verification
├── README.md                               # Comprehensive technical documentation
├── recovery/                               # Dandelion/Blossom TWRP / OrangeFox & vbmeta
│   ├── recovery.img                        # Custom Recovery for Dandelion (ARM64)
│   └── vbmeta.img                          # Blank / patched vbmeta for AVB bypass
└── roms/                                   # ARM64 ROM & Root packages
    ├── README_ROMS.md                      # Instructions, official links & checksums
    └── Magisk-v26.4.apk                    # Root package (flashed/renamed as zip or apk)
```

### Script Execution & Path Standard
- **Relative Binary References**:
  - ADB: `..\bin\adb.exe`
  - Fastboot: `..\bin\fastboot.exe`
  - mtkclient: `..\src\mtkclient\mtk.py`
  - UsbDk Installer: `..\drivers\UsbDk_1.0.22_x64.msi`
- **Script Ergonomics**:
  - `chcp 65001 >nul` at the top of every `.bat`.
  - Quoted paths throughout: `"%~dp0..\bin\fastboot.exe"`.
  - ANSI colors in PowerShell: Yellow for banners, Cyan for guides, Green for success, Red for errors.
  - Interactive confirmations via `Read-Host "Appuyez sur Entree quand pret..."`.
  - Native exit code propagation and validation.

---

## 5. Verification Method

To verify these standards independently:

1. **Verify Binary Paths and Executability**:
   ```powershell
   # From within dandelion_tool/ directory:
   & "..\bin\fastboot.exe" --version
   & "..\bin\adb.exe" version
   python "..\src\mtkclient\mtk.py" --help
   ```
   *Expected*: All commands return version information with exit code `0`.

2. **Verify MT6762 BROM Support in mtkclient**:
   ```powershell
   python -c "from mtkclient.config.brom_config import chipconfig; print(any('6762' in c.name for c in chipconfig.values()))"
   ```
   *Expected*: Outputs `True`.

3. **Verify Non-Regression on Begonia Files**:
   ```powershell
   git status --porcelain
   ```
   *Expected*: Zero modified files. Only untracked files in `dandelion_tool/` and `.agents/`.
