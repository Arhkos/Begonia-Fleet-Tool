# E2E Test Infra: dandelion_tool

## Test Philosophy
- Opaque-box, requirement-driven. No dependency on implementation design.
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Combinatorial + Real-World Workload Testing.
- Target: Verify all R1-R5 requirements and acceptance criteria for Xiaomi Redmi 10A lifecycle tool.

## Feature Inventory Mapping
| # | Feature | Source | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|--------|:------:|:------:|:------:|:------:|
| 1 | Module Isolation & Non-Regression | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ | ✓ |
| 2 | Relative Binary Path Resolution | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ | ✓ |
| 3 | UsbDk Elevation & Driver Check | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 4 | MT6762G BROM Hardware Guidance | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 5 | BROM Bootloader Unlock Syntax | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 6 | FRP Partition Erase Syntax | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 7 | Preloader Safety Safeguards | ORIGINAL_REQUEST R2/R5 | 5 | 5 | ✓ | ✓ |
| 8 | Fastboot AVB Disabling Flags | ORIGINAL_REQUEST R3 | 5 | 5 | ✓ | ✓ |
| 9 | Custom Recovery Flashing Pipeline | ORIGINAL_REQUEST R3 | 5 | 5 | ✓ | ✓ |
| 10 | 64-bit ROM Architecture Specs | ORIGINAL_REQUEST R4 | 5 | 5 | ✓ | ✓ |
| 11 | Magisk Root Deployment | ORIGINAL_REQUEST R4 | 5 | 5 | ✓ | ✓ |
| 12 | Standalone Batch Ergonomics | ORIGINAL_REQUEST R5 | 5 | 5 | ✓ | ✓ |
| 13 | Interactive Menu Experience | ORIGINAL_REQUEST R5 | 5 | 5 | ✓ | ✓ |
| 14 | Technical Documentation Completeness | ORIGINAL_REQUEST R5 | 5 | 5 | ✓ | ✓ |
| 15 | ABI & Root ADB Verification Commands | ORIGINAL_REQUEST Acceptance | 5 | 5 | ✓ | ✓ |

## Test Architecture
- Test Runner: PowerShell test runner `tests\run_tests.ps1` (or automated script) executing opaque-box checks against `dandelion_tool/` deliverables.
- Checks:
  1. Static integrity: Non-regression (`git status` diff check against root/begonia files).
  2. Relative path verification: Relative resolution to `bin\adb.exe`, `bin\fastboot.exe`, `src\mtkclient\mtk.py`, `drivers\UsbDk_1.0.22_x64.msi`.
  3. Syntax verification: Parse batch/PS1 scripts for exact subcommands (`da seccfg unlock`, `e frp`, `--disable-verity --disable-verification`, `chcp 65001`).
  4. Asset presence: Check `recovery/vbmeta.img`, `recovery/recovery.img`, `roms/README_ROMS.md`, `roms/Magisk-v26.4.apk`.
  5. Ergonomics: UTF-8 encoding, pauses, headers, guidance text.
  6. Verification commands: Validation logic for `ro.product.cpu.abi` == `arm64-v8a` and `su -c "id"` == `uid=0(root)`.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| S1 | Out-of-the-box fresh Windows workstation setup | UsbDk check, binary path validation, menu launch | High |
| S2 | Locked FRP & Bootloader BROM unlock workflow | BROM instructions, multi-command execution, safety guards | High |
| S3 | Fastboot custom recovery & AVB bypass workflow | Fastboot flag placement, image flashing, recovery reboot | High |
| S4 | 64-bit ROM transition & Magisk root injection | ADB push/sideload, checksum verification, recovery flashing | High |
| S5 | System verification & QA acceptance audit | `ro.product.cpu.abi` check, `id` root check, non-regression audit | High |
