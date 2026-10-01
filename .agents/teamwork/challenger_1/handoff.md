# Empirical Challenge Report & Handoff — dandelion_tool

**Reviewer Agent**: `challenger_1` (Roles: critic, specialist)  
**Parent Agent**: `4042be46-bc7d-49fd-b893-c25553514f78`  
**Date**: 2026-09-30T21:35:00Z  
**Verdict**: **`REQUEST_CHANGES`**

---

## 1. Observation

### Observation 1.1: E2E Test Suite Tier 2 Fails with Exit Code 1
- **Command**:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2
  ```
- **Result**: Exit code `1`.
- **Verbatim Output**:
  ```text
  [PASS] T2.3.1 : Batch scripts check %errorlevel% after tool execution
  [FAIL] T2.3.2 : Batch scripts maintain pause on termination preventing silent exit
         Reason: All 3 batch scripts maintain terminal pauses
  ...
  FAILED TESTS BREAKDOWN:
    - [Tier 2] T2.3.2: Batch scripts maintain pause on termination preventing silent exit
      Reason: All 3 batch scripts maintain terminal pauses
  ================================================================================
    TEST RUN COMPLETE: FAILURES DETECTED (Exit Code: 1)
  ================================================================================
  ```
- **Code Inspection** (`dandelion_tool\tests\test_dandelion.ps1`, lines 473–476):
  ```powershell
  # Test 2.3.2: Batch scripts do not silently exit on failure
  $noSilentExit = ($unlockContent -match "pause" -and $recContent -match "pause" -and $romContent -match "pause")
  Register-TestResult -TestId "T2.3.2" -Description "Batch scripts maintain pause on termination preventing silent exit" -Passed $noSilentExit -Details "All 3 batch scripts maintain terminal pauses"
  ```
  `$romContent` is defined exclusively at line 283 within `if ($Tier -in @("1", "All"))`. When running `-Tier 2` standalone, `$romContent` is uninitialized (`$null`), causing `$null -match "pause"` to return `$false`.

### Observation 1.2: Tier 1 Regex Parser Exception in `test_dandelion.ps1`
- **Command**:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 1
  ```
- **Verbatim Stderr/Output**:
  ```text
  analyse de "switch\s*\(\\)" - Trop de ).
  Au caractere C:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1:348 : 5
  +     $hasMenuOptions = ($ps1Content -match "switch\s*\(\$choice\)" -or ...
  +     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      + CategoryInfo          : OperationStopped: (:) [], ArgumentException
      + FullyQualifiedErrorId : System.ArgumentException
   
  Register-TestResult : Impossible de traiter la transformation d'argument sur le parametre «Passed». Impossible de 
  convertir la valeur «» en type «System.Boolean».
  ```
- **Code Inspection** (`dandelion_tool\tests\test_dandelion.ps1`, line 348):
  `$hasMenuOptions = ($ps1Content -match "switch\s*\(\$choice\)" ...)`
  In double quotes, `$choice` evaluates to empty string, yielding the invalid regular expression `"switch\s*\(\)"` which throws an `ArgumentException` and aborts registering `T1.6.4`.

### Observation 1.3: CMD Multi-Quote Parsing Bug in Paths with Spaces (`2_INSTALLER_ROM_64BIT_ET_ROOT.bat`)
- **Code Location** (`dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`, line 120):
  ```cmd
  for /f "tokens=*" %%b in ('"%~dp0..\bin\adb.exe" shell su -c "id" 2^>nul') do set ROOT_OUTPUT=%%b
  ```
- **Empirical Test**: Executing this line in a directory containing spaces (`C:\Users\Arhkos\AppData\Local\Temp\dandelion test space\dandelion_tool`):
  ```text
  'C:\Users\Arhkos\AppData\Local\Temp\dandelion' n'est pas reconnu en tant que commande interne ou externe
  ```
- **Impact**: CMD's `for /f ('...')` parser strips the first quote of `"%~dp0...\adb.exe"` and the last quote of `"id"`, causing CMD to attempt execution of the truncated path before the space. The error is silenced by `2^>nul`, `%ROOT_OUTPUT%` remains `"non_defini"`, and root detection fails erroneously.

### Observation 1.4: `<stdin>` Input Redirection Crash in CMD (`2_INSTALLER_ROM_64BIT_ET_ROOT.bat`)
- **Code Location** (`dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`, lines 122–124):
  ```cmd
  echo     Reponse de la commande : %ROOT_OUTPUT%
  echo %ROOT_OUTPUT% | findstr /c:"uid=0(root)" >nul
  ```
- **Empirical Test**: On a device without root or before Magisk authorization, Android shell responds:
  `/system/bin/sh: <stdin>[1]: su: not found`
  When piped unquoted in CMD:
  ```cmd
  set "ROOT_OUTPUT=/system/bin/sh: <stdin>[1]: su: not found" & echo %ROOT_OUTPUT% | findstr /c:"uid=0(root)"
  ```
- **Verbatim Output**:
  ```text
  Le fichier specifie est introuvable.
  ```
  CMD parses `<stdin>` as an input redirection from a non-existent file named `stdin`.

### Observation 1.5: `dandelion_tool.ps1 -Action invalid_param` Hangs on Interactive Stdin
- **Command**:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'dandelion_tool\dandelion_tool.ps1' -Action invalid_param"
  ```
- **Result**: The script does not validate `-Action` or report an error. Switch router hits `Default { Show-Menu }`, clears the console (`Clear-Host`), and hangs waiting for `Read-Host` input. Required killing background task `task-44`.

### Observation 1.6: Disconnected Fastboot Detection Causes Infinite Flash Wait
- **Code Locations**:
  `dandelion_tool\1_FLASHER_RECOVERY_ET_VBMETA.bat`, lines 19–20:
  ```cmd
  "%~dp0..\bin\fastboot.exe" devices
  if %errorlevel% neq 0 ( ... )
  ```
  `dandelion_tool\dandelion_tool.ps1`, lines 156–160:
  ```powershell
  & "$fastbootExe" devices
  if ($LASTEXITCODE -ne 0) { ... }
  ```
- **Empirical Fact**: Fastboot exits with code 0 even when no devices are connected:
  ```text
  bin\fastboot.exe devices
  Exit code: 0
  ```
- **Impact**: When no device is attached, neither script detects the absence of devices. They immediately proceed to `fastboot flash vbmeta ...`, which hangs indefinitely in console waiting for a device (`< waiting for any device >`).

### Observation 1.7: Cross-Device Flashing Risk (Absence of Codename Verification)
- **Empirical Observation**: During test execution, an attached Android device was detected:
  `ec4839c device product:garnet_eea model:2312DRA50G device:garnet transport_id:1`
- **Impact**: Neither `1_FLASHER_RECOVERY_ET_VBMETA.bat` nor `dandelion_tool.ps1` verifies `fastboot getvar product` before executing flash commands. If a user has another device connected in Fastboot mode (e.g. `garnet` or `begonia`), running the flash script will flash Dandelion's `vbmeta.img` and `recovery.img` onto the foreign hardware, soft-bricking it.

### Observation 1.8: Preloader Protection Verification
- **Scripts Checked**:
  - `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`
  - `1_FLASHER_RECOVERY_ET_VBMETA.bat`
  - `2_INSTALLER_ROM_64BIT_ET_ROOT.bat`
  - `MENU_DANDELION.bat`
  - `dandelion_tool.ps1`
- **Result**: Zero occurrences of `preloader`, `boot1`, or `boot2` erasure or flash commands across all files. BROM unlock command strictly targets:
  `da seccfg unlock;e frp;e metadata,userdata,md_udc;reset`

---

## 2. Logic Chain

1. **Test Runner Correctness**:
   - Original dispatch explicitly instructed: `Execute the project E2E test suite: powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2 and -Tier 4`.
   - Running Tier 2 resulted in an exit code of 1 due to assertion failure in `T2.3.2`.
   - Inspection proves this is caused by variable leakage where `$romContent` was only defined in Tier 1. Running Tier 2 independently is broken.
   - Furthermore, Tier 1 contains a regex string formatting bug causing an unhandled parser exception in `T1.6.4`.
   - Therefore, the test suite itself has defects that cause CI/verification runs of Tier 2 to fail.

2. **Adversarial Path Handling**:
   - In `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:120`, the command inside `for /f ('...')` contains multiple quoted tokens (`"%~dp0..\bin\adb.exe"` and `"id"`).
   - Under Windows CMD semantics, CMD strips the first and last quote of the entire command string when multiple quotes are present.
   - In any environment where the workspace path has spaces, `adb.exe` fails to execute, returning an unquoted truncated directory path error (`'C:\Users\...' n'est pas reconnu`).
   - Because stdout/stderr are redirected with `2^>nul`, the failure is completely silenced, and the root status is falsely reported as failed.
   - Similarly, in line 123, piping unquoted `%ROOT_OUTPUT%` when `su` is missing creates an invalid file redirection from `stdin`.

3. **CLI Robustness**:
   - Executing `dandelion_tool.ps1 -Action invalid_param` defaults to `Show-Menu`, which initiates an interactive `Read-Host` loop.
   - In scripted or automated contexts, this hangs the process rather than terminating with an error and non-zero exit code.

4. **Hardware Safety**:
   - Preloader safety assertions are satisfied (no `boot1`/`boot2`/`preloader` modification).
   - However, device presence detection in fastboot relies solely on `%errorlevel%`/`$LASTEXITCODE`, which is 0 even when no device is connected, leading to infinite hangs.
   - Additionally, lack of `fastboot getvar product` validation introduces cross-flashing risk when multiple/foreign devices are connected.

---

## 3. Caveats

- Hardware BROM handshake was not executed on a physical Redmi 10A device (as none was physically connected in BROM mode during this test session). However, the command-line payload string `da seccfg unlock;e frp;e metadata,userdata,md_udc;reset` was fully validated against `mtkclient` command parser syntax.
- The connected device `garnet` (Redmi Note 13 Pro 5G) was deliberately excluded from destructive operations; only benign ADB checks and immediate cleanup of test artifacts were performed.

---

## 4. Conclusion & Required Changes

The verdict is **`REQUEST_CHANGES`**.

The following changes are required:
1. **Fix `dandelion_tool\tests\test_dandelion.ps1`**:
   - In Tier 2: Read `$romContent` locally or ensure `$romContent` is initialized before Group 3 executes (e.g. `$romContent = if (Test-Path "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat") { Get-Content "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat" -Raw -Encoding UTF8 } else { "" }`).
   - In Tier 1 line 348: Fix the regex string escaping for `$choice` by using single quotes: `($ps1Content -match 'switch\s*\(\$choice\)' -or ...)` so PowerShell does not interpolate `$choice`.
2. **Fix `dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`**:
   - In line 120: Avoid multi-quote stripping in `for /f` by using `usebackq` or calling ADB without inner quotes (e.g. `for /f "tokens=*" %%b in ('call "%~dp0..\bin\adb.exe" shell su -c id 2^>nul') do set ROOT_OUTPUT=%%b`).
   - In line 123: Quote `%ROOT_OUTPUT%` during echo/findstr: `echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul` to prevent `<stdin>` redirection crashes.
   - In line 49: Quote filenames in echo: `echo [*] Copie de la ROM detectee : "%%~nxf" ...`.
3. **Fix `dandelion_tool\dandelion_tool.ps1`**:
   - Add parameter validation or reject unknown actions in the switch `Default` block:
     ```powershell
     Default { 
         Write-Host "[-] Action invalide : '$Action'. Actions valides : menu, check, install-usbdk, unlock, recovery, deploy-rom, verify." -ForegroundColor Red
         exit 1 
     }
     ```
   - In `Flash-Recovery-Fastboot`: Check that `fastboot devices` output is non-empty before attempting to flash:
     ```powershell
     $fbDev = (& "$fastbootExe" devices).Trim()
     if ([string]::IsNullOrWhiteSpace($fbDev)) {
         Write-Host "[-] Aucun peripherique Fastboot detecte ! Connectez le telephone en mode Fastboot." -ForegroundColor Red
         return
     }
     ```
   - In `1_FLASHER_RECOVERY_ET_VBMETA.bat`: Check that output of `fastboot devices` is non-empty before proceeding with the flash.
   - In `Push-ROM-Files-ADB`: Add `else` block to log error if Magisk upload fails (`$LASTEXITCODE -ne 0`).

---

## 5. Verification Method

To verify these fixes:
1. Run Tier 2 standalone:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2
   ```
   **Pass condition**: Exits with code `0`, T2.3.2 passes.
2. Run Tier 1 standalone:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 1
   ```
   **Pass condition**: Exits with code `0`, no regex ArgumentException, T1.6.4 passes.
3. Test invalid parameter handling:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\dandelion_tool.ps1" -Action invalid_param
   ```
   **Pass condition**: Exits immediately with error message and exit code `1` without hanging.
4. Test space-path handling in `2_INSTALLER_ROM_64BIT_ET_ROOT.bat`:
   Run the root detection snippet from a path containing spaces.
   **Pass condition**: Does not fail with `'C:\...' n'est pas reconnu`.

---

## Adversarial Challenge Matrix

| ID | Category | Challenge / Stress Test | Expected Behavior | Actual Behavior | Pass/Fail |
|---|---|---|---|---|---|
| **C1** | Test Runner | `run_tests.ps1 -Tier 2` standalone | Pass (Exit Code 0) | Exits with Code 1 (T2.3.2 fails due to undefined `$romContent`) | **FAIL** |
| **C2** | Test Runner | `run_tests.ps1 -Tier 1` AST/Regex | Clean regex execution | Throws `ArgumentException` at line 348 on `switch\s*\(\$choice\)` | **FAIL** |
| **C3** | Path Robustness | Project in path with spaces (`su -c "id"`) | Clean ADB execution | CMD drops quotes, outputs `'C:\...' n'est pas reconnu`, root check fails | **FAIL** |
| **C4** | Shell Robustness | Root output containing `<stdin>[1]: su: not found` | Graceful failure message | CMD attempts file redirection from `stdin`, crashes with `Le fichier specifie est introuvable` | **FAIL** |
| **C5** | CLI Syntax | `dandelion_tool.ps1 -Action invalid_param` | Error message & exit 1 | Hangs on interactive `Read-Host` menu loop | **FAIL** |
| **C6** | Hardware Guard | Fastboot flash when no device connected | Error message and exit | Hangs indefinitely on `< waiting for any device >` | **FAIL** |
| **C7** | Hardware Guard | Fastboot flash with foreign device connected | Model verification prevents flash | Unconditional flash would flash foreign device | **FAIL** |
| **C8** | Preloader Guard | Script scan for `boot1`/`boot2`/`preloader` erasure | Zero erasure commands | 0 erase/flash commands found across all scripts | **PASS** |
| **C9** | Test Runner | `run_tests.ps1 -Tier 4` | Pass (Exit Code 0) | All 5 scenarios passed | **PASS** |
| **C10** | Non-Regression | Root Begonia files intact | `git status` clean outside `dandelion_tool/` | 0 modifications to existing files | **PASS** |
