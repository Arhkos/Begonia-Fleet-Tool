# Forensic Integrity Audit Report — Dandelion Tool

**Work Product**: `dandelion_tool/` implementation and tests  
**Profile**: General Project (Demo Mode)  
**Auditor**: `auditor_1` (Forensic Integrity Auditor)  
**Verdict**: **INTEGRITY VIOLATION**

---

## 1. Observation

### Observation 1: Non-Regression & Workspace Isolation
- Command executed: `git diff HEAD`
  - Output: Empty (0 modifications to tracked repository files).
- Command executed: `git status -s bin drivers recovery roms stock_firmware begonia_tool.ps1 MENU_GENERAL.bat README.md README.fr.md`
  - Output: Empty. All Begonia root files remain 100% untouched.
- Filesystem inspection: `dandelion_tool/` contains its own dedicated structure:
  - `dandelion_tool/recovery/` (`vbmeta.img`, `recovery.img`)
  - `dandelion_tool/roms/` (`Magisk-v26.4.apk`, `README_ROMS.md`)
  - `dandelion_tool/tests/` (`run_tests.ps1`, `test_dandelion.ps1`)
  - `dandelion_tool/0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`
  - `dandelion_tool/1_FLASHER_RECOVERY_ET_VBMETA.bat`
  - `dandelion_tool/2_INSTALLER_ROM_64BIT_ET_ROOT.bat`
  - `dandelion_tool/MENU_DANDELION.bat`
  - `dandelion_tool/dandelion_tool.ps1`
  - `dandelion_tool/README.md`
- Relative traversal verification:
  - `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat:65`: `python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`
  - `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat:35`: `powershell -NoProfile -Command "Start-Process msiexec.exe -ArgumentList '/i', '\"%~dp0..\drivers\UsbDk_1.0.22_x64.msi\"' -Verb RunAs -Wait"`
  - `1_FLASHER_RECOVERY_ET_VBMETA.bat:19,32,44,58`: references `"%~dp0..\bin\fastboot.exe"`, `"%~dp0recovery\vbmeta.img"`, `"%~dp0recovery\recovery.img"`.
  - `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:32,50,62,102,107,120`: references `"%~dp0..\bin\adb.exe"`, `"%~dp0roms\Magisk-v26.4.apk"`.
  - `dandelion_tool.ps1:16-19`: `$fastbootExe = "$WorkspaceRoot\bin\fastboot.exe"`, `$adbExe = "$WorkspaceRoot\bin\adb.exe"`, `$mtkPy = "$WorkspaceRoot\src\mtkclient\mtk.py"`, `$usbdkMsi = "$WorkspaceRoot\drivers\UsbDk_1.0.22_x64.msi"`.
  - Zero hardcoded drive letters (`C:\` or `D:\`) found in any script.

### Observation 2: Asset Authenticity
- `dandelion_tool\recovery\vbmeta.img`:
  - Length: `4096` bytes.
  - Header Magic (bytes 0..3): `AVB0` (`0x41 0x56 0x42 0x30`).
  - Flags (offset 120, uint32 big-endian): `0x00000002` (`AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED` per libavb spec).
  - SHA-256: `F6DA5489FD877CB69CF61FA721CFD6D77E530084AEFE9B96664F818947FF61F6`.
- `dandelion_tool\recovery\recovery.img`:
  - Length: `67108864` bytes (64 MB).
  - Header Magic (bytes 0..7): `ANDROID!` (`0x41 0x4E 0x44 0x52 0x4F 0x49 0x44 0x21`).
  - SHA-256: `40B5EA262E08BE110302C8F73EEC8DCF16ACC051BE54217735D5DED5B3172DA9`.
- `dandelion_tool\roms\Magisk-v26.4.apk`:
  - Length: `12526383` bytes (12.52 MB, > 10MB).
  - Header Magic (bytes 0..3): `PK\x03\x04` (`0x50 0x4B 0x03 0x04`).
  - SHA-256: `543A96FE26C012D99BAF3A3AA5A97B80508D67CC641AF7C12CE9F7B226B2B889` (verbatim match with `README_ROMS.md`).
  - Zip entries: 1100 internal entries verified including `lib/arm64-v8a/libmagisk64.so`, `lib/arm64-v8a/libmagiskboot.so`, `lib/arm64-v8a/libmagiskinit.so`, `lib/armeabi-v7a/libmagisk32.so`, `assets/util_functions.sh`, `classes.dex`.

### Observation 3: Real Execution vs. Facades
- No echo statement simulations posing as successful binary execution were found.
- The scripts genuinely execute real binaries (`fastboot.exe`, `adb.exe`, `python ... mtk.py`, `msiexec.exe`) and check exit status via `%errorlevel%` and `$LASTEXITCODE`.
- No hardcoded test passes (`-Passed $true`) exist in `test_dandelion.ps1`. Test conditions evaluate real dynamic variables (`$isClean`, `$begoniaIntact`, `$adbExecutes`, `$fbExecutes`, `$mtkExecutes`, `$usbdkValid`, `$ast`, etc.).

### Observation 4: Test Suite Defect & Fake Pass Signal in `test_dandelion.ps1`
- File inspection: In `dandelion_tool\tests\test_dandelion.ps1` lines 348–350:
  ```powershell
  348:     $hasMenuOptions = ($ps1Content -match "switch\s*\(\$choice\)" -or $ps1Content -match "Show-Menu") -and 
  349:                       ($ps1Content -match "seccfg|Bootloader" -and $ps1Content -match "recovery|vbmeta" -and $ps1Content -match "ROM|Root")
  350:     Register-TestResult -TestId "T1.6.4" -Description "dandelion_tool.ps1 provides full interactive menu lifecycle options" -Passed $hasMenuOptions -Details "Menu lifecycle routing detected"
  ```
- Unescaped variable in regex: At line 348, `\$choice` is placed inside double quotes `"switch\s*\(\$choice\)"`. In PowerShell, `$choice` evaluates to empty string at runtime, producing the broken regex pattern `"switch\s*\(\)"`.
- Verbatim runtime exception during test execution:
  ```
  analyse de "switch\s*\(\\)" - Trop de ).
  Au caractère C:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1:348 : 5
  +     $hasMenuOptions = ($ps1Content -match "switch\s*\(\$choice\)" -or ...
  +     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      + CategoryInfo          : OperationStopped: (:) [], ArgumentException
      + FullyQualifiedErrorId : System.ArgumentException
   
  Register-TestResult : Impossible de traiter la transformation d'argument sur le paramètre 'Passed'. Impossible de 
  convertir la valeur '' en type 'System.Boolean'. Les paramètres booléens acceptent seulement des valeurs booléennes et 
  des nombres, tels que $True, $False, 1 ou 0.
  Au caractère C:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1:350 : 133
  + ... l interactive menu lifecycle options" -Passed $hasMenuOptions -Detail ...
  +                                                   ~~~~~~~~~~~~~~~
      + CategoryInfo          : InvalidData : (:) [Register-TestResult], ParameterBindingArgumentTransformationException
      + FullyQualifiedErrorId : ParameterArgumentTransformationError,Register-TestResult
  ```
- Silenced failure & discrepancy in test count:
  - There are **74 unique test IDs** defined in `test_dandelion.ps1` (from `T1.1.1` to `T4.5`).
  - Because `T1.6.4` crashed on parameter binding, `Register-TestResult` was NEVER called for `T1.6.4`.
  - `$global:TestResults` received only 73 entries.
  - The runner reported:
    ```
    TOTAL TESTS RUN : 73
    PASSED          : 73
    FAILED          : 0
    OVERALL RATE    : 100 %
    [SUCCESS] All E2E test assertions passed successfully!
    TEST RUN COMPLETE: ALL CHECKS PASSED (Exit Code: 0)
    ```
  - This constitutes a **fake pass signal**: an uncaught assertion exception was silently swallowed by `$ErrorActionPreference = "Continue"`, dropping test `T1.6.4` entirely and falsely attesting 100% completion.

### Observation 5: Broken Tier Isolation (`run_tests.ps1 -Tier 2`)
- Command executed: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2`
- Result:
  ```
    [FAIL] T2.3.2 : Batch scripts maintain pause on termination preventing silent exit
           Reason: All 3 batch scripts maintain terminal pauses
  ...
  FAILED TESTS BREAKDOWN:
    - [Tier 2] T2.3.2: Batch scripts maintain pause on termination preventing silent exit
      Reason: All 3 batch scripts maintain terminal pauses
  TEST RUN COMPLETE: FAILURES DETECTED (Exit Code: 1)
  ```
- Root cause: In `test_dandelion.ps1` line 474:
  `$noSilentExit = ($unlockContent -match "pause" -and $recContent -match "pause" -and $romContent -match "pause")`
  The variable `$romContent` was only defined in Tier 1 (`if ($Tier -in @("1", "All"))`). When Tier 2 is invoked independently, `$romContent` is `$null`, causing Test `T2.3.2` to fail deterministically with Exit Code 1.

---

## 2. Logic Chain

1. **Step 1 — Integrity Rules**:
   Per the forensic mandate, work products must be rejected if ANY check fails:
   - "Check all scripts and tests for hardcoded dummy/facade implementations or fake pass signals."
   - "The build must succeed and tests must execute — a project that doesn't build or whose tests don't run is automatically flagged."
   - "Block on failure: If ANY check fails, the verdict is INTEGRITY VIOLATION and the work product must be rejected."
2. **Step 2 — Evaluation of Observation 4**:
   `test_dandelion.ps1` contains an unhandled `ArgumentException` and `ParameterBindingArgumentTransformationException` at lines 348–350 during execution of Test `T1.6.4`.
   The runner reported 73/73 tests passed with exit code 0 when there are actually 74 tests defined. The crash silently dropped `T1.6.4` from the test registry without flagging a failure. This represents a fake pass signal and an unhandled test crash.
3. **Step 3 — Evaluation of Observation 5**:
   Running the test suite for Tier 2 (`run_tests.ps1 -Tier 2`) fails with Exit Code 1 (`[FAIL] T2.3.2`) due to an undeclared variable dependency on Tier 1. Tests in a modular test runner must execute independently without crashing or failing due to state leakage.
4. **Step 4 — Conclusion of Violation**:
   Because the test suite exhibits a fake pass signal (uncaught crash masked as 100% pass) and fails when running `-Tier 2`, it violates the core integrity standards of genuine behavioral verification and test correctness. Under non-negotiable forensic rules, the auditor must not silently fix these errors and must issue an INTEGRITY VIOLATION.

---

## 3. Caveats

- **No caveats regarding implementation quality**: The batch scripts (`0_...bat`, `1_...bat`, `2_...bat`), PowerShell script (`dandelion_tool.ps1`), images (`recovery.img`, `vbmeta.img`), Magisk package, and documentation are authentic, well-crafted, and adhere to requirements R1 through R5.
- The failure is isolated strictly to `dandelion_tool\tests\test_dandelion.ps1`:
  1. Regex escaping bug on line 348 (`"switch\s*\(\$choice\)"` -> should be `'switch\s*\(\$choice\)'` or `"switch\s*\(\`$choice\)"`).
  2. Uninitialized `$romContent` variable on line 474 for Tier 2 standalone execution.
- Physical flashing of real hardware was not performed as this is a software development workstation without a physical Redmi 10A connected.

---

## 4. Conclusion

**Verdict: INTEGRITY VIOLATION**

The work product cannot be certified as CLEAN because:
1. **Fake Pass Signal / Test Crash Suppression**: In `test_dandelion.ps1` lines 348-350, Test `T1.6.4` crashes due to an unescaped variable in the regex pattern, causing a `ParameterBindingArgumentTransformationException`. The test is dropped from the registry, yet the test runner emits exit code 0 and reports `TOTAL TESTS RUN: 73, PASSED: 73, FAILED: 0, [SUCCESS] All E2E test assertions passed successfully!`, concealing the crashed test.
2. **Modular Test Suite Failure**: Executing `powershell -File "dandelion_tool\tests\run_tests.ps1" -Tier 2` results in a test failure (`T2.3.2 [FAIL]`) and Exit Code 1 due to `$romContent` being uninitialized when Tier 1 is skipped.

The work product must be remediated by fixing the two bugs in `dandelion_tool\tests\test_dandelion.ps1` and re-submitting for audit.

---

## 5. Verification Method

To independently reproduce and verify this audit:

1. **Verify the T1.6.4 test crash and dropped count during `-Tier All`**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "$out = & 'dandelion_tool\tests\run_tests.ps1' -Tier All 2>&1; $out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | Select-Object -ExpandProperty Exception"
   ```
   *Expected result*: Displays `ArgumentException` ("Trop de ).") and `ParameterBindingArgumentTransformationException`.
   Check total registered count:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All
   ```
   *Notice*: Outputs `TOTAL TESTS RUN : 73` even though 74 tests are defined.

2. **Verify Tier 2 standalone failure**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2
   ```
   *Expected result*: Exits with code 1, reporting `[FAIL] T2.3.2`.

3. **Verify Asset Authenticity**:
   ```powershell
   # vbmeta AVB0 and flag check
   $vb = [System.IO.File]::ReadAllBytes('dandelion_tool\recovery\vbmeta.img')
   [System.Text.Encoding]::ASCII.GetString($vb, 0, 4) # Returns 'AVB0'
   [System.BitConverter]::ToUInt32($vb[123..120], 0).ToString('X8') # Returns '00000002'
   
   # recovery ANDROID! magic check
   $rec = [System.IO.File]::ReadAllBytes('dandelion_tool\recovery\recovery.img')
   [System.Text.Encoding]::ASCII.GetString($rec, 0, 8) # Returns 'ANDROID!'
   
   # Magisk size and PK magic check
   (Get-Item 'dandelion_tool\roms\Magisk-v26.4.apk').Length # Returns 12526383 (>10MB)
   ```

4. **Verify Non-Regression**:
   ```cmd
   git diff HEAD
   ```
   *Expected result*: 0 tracked files modified.
