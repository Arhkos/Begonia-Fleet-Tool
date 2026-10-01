# Project: dandelion_tool — Xiaomi Redmi 10A Automation Tooling

## Architecture
Dedicated, isolated module `dandelion_tool/` for the lifecycle automation of Xiaomi Redmi 10A (3GB RAM, MT6762G Helio G25, dandelion/blossom):
- Reuses common binaries from `..\bin\adb.exe`, `..\bin\fastboot.exe`, `..\src\mtkclient`, `..\drivers\UsbDk_1.0.22_x64.msi`.
- Zero modifications to existing Begonia files at root or in `recovery/`, `roms/`, `stock_firmware/`.
- Dual interface: 1-click standalone batch scripts (`0_...`, `1_...`, `2_...`) and full interactive PowerShell menu (`MENU_DANDELION.bat` -> `dandelion_tool.ps1`).

```
peaceful-babbage/
├── bin/ [SHARED - READ ONLY]
├── drivers/ [SHARED - READ ONLY]
├── src/mtkclient/ [SHARED - READ ONLY]
└── dandelion_tool/ [NEW MODULE - 100% ISOLATED]
    ├── MENU_DANDELION.bat
    ├── dandelion_tool.ps1
    ├── 0_DEVERROUILLER_BOOTLOADER_DANDELION.bat
    ├── 1_FLASHER_RECOVERY_ET_VBMETA.bat
    ├── 2_INSTALLER_ROM_64BIT_ET_ROOT.bat
    ├── README.md
    ├── recovery/
    │   ├── recovery.img
    │   └── vbmeta.img
    └── roms/
        ├── README_ROMS.md
        └── Magisk-v26.4.apk
```

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Module Isolation | Dedicated `dandelion_tool/` subtree with no changes to Begonia root/subfolders | M1 | ORIGINAL_REQUEST R1 |
| 2 | Relative Binary Reuse | Relative references to `..\bin\adb.exe`, `..\bin\fastboot.exe`, `..\src\mtkclient` | M1 | ORIGINAL_REQUEST R1 |
| 3 | UsbDk Driver Automation | Driver check and silent/elevated installation from `..\drivers\UsbDk_1.0.22_x64.msi` | M2 | ORIGINAL_REQUEST R2 |
| 4 | BROM Hardware Sequence | Documented & guided Vol+ + Vol- button sequence on powered-off phone | M2 | ORIGINAL_REQUEST R2 |
| 5 | BROM Bootloader Unlock | `python "..\src\mtkclient\mtk.py" da seccfg unlock` execution | M2 | ORIGINAL_REQUEST R2 |
| 6 | FRP Partition Erase | `python "..\src\mtkclient\mtk.py" e frp` execution | M2 | ORIGINAL_REQUEST R2 |
| 7 | Atomic Multi-Command | Single-session execution `multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"` | M2 | ORIGINAL_REQUEST R2 |
| 8 | Preloader Protection | Guard against modifying or erasing `boot1`/`boot2` hardware preloader | M2 | ORIGINAL_REQUEST R2 & R5 |
| 9 | Fastboot AVB Disabling | `--disable-verity --disable-verification flash vbmeta vbmeta.img` | M3 | ORIGINAL_REQUEST R3 |
| 10 | Custom Recovery Flashing | `fastboot flash recovery recovery.img` for blossom/dandelion | M3 | ORIGINAL_REQUEST R3 |
| 11 | Anti-Overwrite Recovery Boot | Immediate reboot to recovery (`fastboot reboot recovery` / Vol+ hold) | M3 | ORIGINAL_REQUEST R3 |
| 12 | 64-bit Custom ROM Pipeline | crDroid 9 / LineageOS 20 ARM64 blossom integration & documentation | M4 | ORIGINAL_REQUEST R4 |
| 13 | 64-bit Root Integration | Magisk v26+ deployment and flashing instructions for ARM64 | M4 | ORIGINAL_REQUEST R4 |
| 14 | ROM/Root Push Automation | Automated ADB push/sideload workflow into recovery environment | M4 | ORIGINAL_REQUEST R4 |
| 15 | Standalone Batch Scripts | 1-click batch scripts: `0_...`, `1_...`, `2_...` with UTF-8 and pauses | M5 | ORIGINAL_REQUEST R5 |
| 16 | Interactive Fleet Menu | `MENU_DANDELION.bat` and `dandelion_tool.ps1` with environment diagnostics | M5 | ORIGINAL_REQUEST R5 |
| 17 | Technical Guide | Complete `README.md` with hardware keys, preloader safety, workflow | M5 | ORIGINAL_REQUEST R5 |
| 18 | ABI Verification Command | `adb shell getprop ro.product.cpu.abi` returning `arm64-v8a` | M4, M5, E2E | ORIGINAL_REQUEST Acceptance |
| 19 | Root Verification Command | `adb shell su -c "id"` returning `uid=0(root)` | M4, M5, E2E | ORIGINAL_REQUEST Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Directory Scaffold & Relative Paths | Create `dandelion_tool/`, `recovery/`, `roms/`, establish relative path validation | None | DONE |
| M2 | Bootloader & FRP Unlock Subsystem | Create `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`, UsbDk check, BROM unlock | M1 | DONE |
| M3 | Recovery & AVB Disabling Subsystem | Create `1_FLASHER_RECOVERY_ET_VBMETA.bat`, vbmeta.img, recovery.img | M1 | DONE |
| M4 | 64-bit ROM & Root Deployment | Create `2_INSTALLER_ROM_64BIT_ET_ROOT.bat`, `roms/README_ROMS.md`, Magisk | M1 | DONE |
| M5 | Interface & Documentation | Create `MENU_DANDELION.bat`, `dandelion_tool.ps1`, `README.md` | M2, M3, M4 | DONE |
| M6 | Final Acceptance & E2E Validation | Pass 100% of E2E verification tests & non-regression audit | M5 | DONE |

## Interface Contracts
### Binary References Contract
All scripts located in `dandelion_tool/` MUST reference external binaries using exact relative paths:
- Fastboot: `"%~dp0..\bin\fastboot.exe"` (CMD) or `"$WorkspaceRoot\bin\fastboot.exe"` (PS)
- ADB: `"%~dp0..\bin\adb.exe"` (CMD) or `"$WorkspaceRoot\bin\adb.exe"` (PS)
- mtkclient: `python "%~dp0..\src\mtkclient\mtk.py"` (CMD) or `& python "$WorkspaceRoot\src\mtkclient\mtk.py"` (PS)
- UsbDk Installer: `"%~dp0..\drivers\UsbDk_1.0.22_x64.msi"` (CMD) or `"$WorkspaceRoot\drivers\UsbDk_1.0.22_x64.msi"` (PS)

### Command Exit Code Contract
- Every batch script must enforce `chcp 65001 >nul` at line 2.
- Every script must check `%errorlevel%` after external binary invocations and halt on error with `pause` before exit.
- PowerShell script must verify `$LASTEXITCODE` and display standard `[+]` (Green) or `[-]` (Red) status banners.

### Verification Contract
- Architecture validation: `adb shell getprop ro.product.cpu.abi` must evaluate to `arm64-v8a`.
- Root privilege validation: `adb shell su -c "id"` must evaluate to containing `uid=0(root)`.

## Code Layout
```
dandelion_tool/
├── MENU_DANDELION.bat                       # CMD entrypoint -> dandelion_tool.ps1
├── dandelion_tool.ps1                       # Interactive PowerShell management tool
├── 0_DEVERROUILLER_BOOTLOADER_DANDELION.bat  # 1-click BROM bootloader unlock & FRP erase
├── 1_FLASHER_RECOVERY_ET_VBMETA.bat         # 1-click Fastboot AVB disable & recovery flash
├── 2_INSTALLER_ROM_64BIT_ET_ROOT.bat        # 1-click ROM/Root push & ADB verification
├── README.md                                # Full documentation and technical manual
├── recovery/
│   ├── recovery.img                         # Custom recovery image (OrangeFox / TWRP)
│   └── vbmeta.img                           # AVB disable vbmeta image
└── roms/
    ├── README_ROMS.md                       # ROM download links, checksums, instructions
    └── Magisk-v26.4.apk                     # Magisk root archive
```
