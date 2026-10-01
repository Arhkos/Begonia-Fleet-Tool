# Forensic Integrity Audit Report — Dandelion Tool (Iteration 2)

**Work Product**: `dandelion_tool/` implementation and tests  
**Profile**: General Project (Demo Mode per `ORIGINAL_REQUEST.md`)  
**Auditor**: `auditor_iter2_2` (Forensic Integrity Auditor)  
**Verdict**: **CLEAN**

---

### Phase Results Summary
- **T1.6.4 Test Registration & Clean Execution**: PASS — Single-quoted regex `'switch\s*\(\$choice\)'` resolves interpolation crash; registers and passes with 0 exceptions.
- **Total Test Count in `-Tier All`**: PASS — EXACTLY 74 tests registered, executed, and passed (38 in Tier 1, 25 in Tier 2, 6 in Tier 3, 5 in Tier 4).
- **Tier 2 Standalone Independence (`run_tests.ps1 -Tier 2`)**: PASS — Pre-flight global initialization of `$romContent` resolves state leakage; passes 25/25 with exit code 0.
- **Anti-Cheat & Authenticity**: PASS — 0 hardcoded test passes (`-Passed $true`), 0 facade implementations, genuine binary invocations (`adb.exe`, `fastboot.exe`, `mtk.py`, `msiexec.exe`).
- **Asset Authenticity**: PASS — `vbmeta.img` (4096 B, `AVB0`, flag `0x02`), `recovery.img` (64 MB, `ANDROID!`), `Magisk-v26.4.apk` (12.52 MB, `PK`, 5 arm64-v8a binaries).
- **Non-Regression & Isolation**: PASS — `git diff HEAD` is empty (0 tracked files modified); Begonia root files remain 100% intact.
- **Full Test Suite Independent Execution**: PASS — 74/74 assertions pass, exit code 0, 0 ErrorRecords.

---

## 1. Observation

### Observation 1.1: Verification of T1.6.4 Remediation in `test_dandelion.ps1`
- **File & Line**: `dandelion_tool\tests\test_dandelion.ps1:363-366`
  ```powershell
  # Test 1.6.4: Interactive menu options mapped
  $hasMenuOptions = ($ps1Content -match 'switch\s*\(\$choice\)' -or $ps1Content -match "Show-Menu") -and 
                    ($ps1Content -match "seccfg|Bootloader" -and $ps1Content -match "recovery|vbmeta" -and $ps1Content -match "ROM|Root")
  Register-TestResult -TestId "T1.6.4" -Description "dandelion_tool.ps1 provides full interactive menu lifecycle options" -Passed $hasMenuOptions -Details "Menu lifecycle routing detected"
  ```
- **Execution & Exception Check**:
  Command executed:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 1
  ```
  Output snippet:
  ```
    [PASS] T1.6.4 : dandelion_tool.ps1 provides full interactive menu lifecycle options
  ...
  TOTAL TESTS RUN : 38
  PASSED          : 38
  FAILED          : 0
  OVERALL RATE    : 100 %
  TEST RUN COMPLETE: ALL CHECKS PASSED (Exit Code: 0)
  ```
- **Error Trapping**: Executing `test_tier_errors.ps1` querying `[System.Management.Automation.ErrorRecord]` confirmed **0 exceptions** thrown. Neither `System.ArgumentException` nor `ParameterBindingArgumentTransformationException` occurred.

### Observation 1.2: Verification of Standalone Tier 2 Independence
- **File & Lines**: `dandelion_tool\tests\test_dandelion.ps1:46-51`
  ```powershell
  # Global pre-flight content initialization for standalone Tier isolation
  $unlockContent  = if (Test-Path $unlockScript)   { Get-Content $unlockScript -Raw -Encoding UTF8 } else { "" }
  $recContent     = if (Test-Path $recoveryScript) { Get-Content $recoveryScript -Raw -Encoding UTF8 } else { "" }
  $romContent     = if (Test-Path $romScript)      { Get-Content $romScript -Raw -Encoding UTF8 } else { "" }
  $ps1Content     = if (Test-Path $menuPs1)        { Get-Content $menuPs1 -Raw -Encoding UTF8 } else { "" }
  $readmeContent  = if (Test-Path $readmeMd)       { Get-Content $readmeMd -Raw -Encoding UTF8 } else { "" }
  ```
- **Execution**:
  Command executed:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2
  ```
  Output snippet:
  ```
    [PASS] T2.3.2 : Batch scripts maintain pause on termination preventing silent exit
  ...
  TOTAL TESTS RUN : 25
  PASSED          : 25
  FAILED          : 0
  OVERALL RATE    : 100 %
  TEST RUN COMPLETE: ALL CHECKS PASSED (Exit Code: 0)
  ```
- **Result**: Tier 2 executed completely independently without relying on Tier 1 state, exiting with code 0 and 0 failures.

### Observation 1.3: Total Registered Test Count in `-Tier All`
- **Execution**:
  Command executed:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All
  ```
  Output summary:
  ```
  Tier   Total Tests Passed Failed Pass Rate
  ----   ----------- ------ ------ ---------
  Tier 1          38     38      0 100 %    
  Tier 2          25     25      0 100 %    
  Tier 3           6      6      0 100 %    
  Tier 4           5      5      0 100 %    

  TOTAL TESTS RUN : 74
  PASSED          : 74
  FAILED          : 0
  OVERALL RATE    : 100 %
  [SUCCESS] All E2E test assertions passed successfully!
  TEST RUN COMPLETE: ALL CHECKS PASSED (Exit Code: 0)
  ```
- **Registration Audit** (via `check_anti_cheat.ps1`):
  - Unique Test IDs defined in source: **74** (`T1.1.1` through `T4.5`)
  - Runtime Registered Tests in `$global:TestResults`: **74**
  - Missing tests from runtime: **0**

### Observation 1.4: Anti-Cheat & Authenticity Analysis
- **Hardcoded Result Audit**:
  - Searched `dandelion_tool\tests\test_dandelion.ps1` for `-Passed $true` or `-Passed 1`: **0 occurrences found**.
  - All 74 assertions dynamically evaluate script content, filesystem properties, AST syntax parsing, or live binary outputs.
- **Genuine Binary Invocations**:
  - `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat:66`: `python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`
  - `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat:36`: `powershell -NoProfile -Command "$proc = Start-Process msiexec.exe -ArgumentList '/i', ('\"' + $env:USBDK_MSI + '\"') -Verb RunAs -Wait -PassThru; exit $proc.ExitCode"`
  - `1_FLASHER_RECOVERY_ET_VBMETA.bat:20,45,65,77,91`: invokes `"%~dp0..\bin\fastboot.exe"` for `devices`, `getvar product`, `flash vbmeta`, `flash recovery`, and `reboot recovery`.
  - `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:32,50,62,102,107,120`: invokes `"%~dp0..\bin\adb.exe"` for `devices`, `push`, `wait-for-device`, `shell getprop ro.product.cpu.abi`, and `shell su -c id`.
  - `dandelion_tool.ps1:134,156,171,179,188,204,210,221,248,252,266`: invokes `python $mtkPy`, `& "$fastbootExe"`, and `& "$adbExe"`.
- **Pre-populated Artifact Check**:
  - Recursively scanned `dandelion_tool/`: 0 `.log`, 0 `.out`, and 0 fabricated verification result files present.

### Observation 1.5: Asset Authenticity
- Independent inspection executed via `verify_assets.ps1`:
  1. `dandelion_tool\recovery\vbmeta.img`:
     - File size: `4096` bytes.
     - Header Magic (bytes 0..3): `AVB0` (`0x41 0x56 0x42 0x30`).
     - Flags (offset 120, uint32 big-endian): `0x00000002` (`AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED`).
     - SHA-256: `F6DA5489FD877CB69CF61FA721CFD6D77E530084AEFE9B96664F818947FF61F6`.
  2. `dandelion_tool\recovery\recovery.img`:
     - File size: `67108864` bytes (64 MB).
     - Header Magic (bytes 0..7): `ANDROID!` (`0x41 0x4E 0x44 0x52 0x4F 0x49 0x44 0x21`).
     - SHA-256: `40B5EA262E08BE110302C8F73EEC8DCF16ACC051BE54217735D5DED5B3172DA9`.
  3. `dandelion_tool\roms\Magisk-v26.4.apk`:
     - File size: `12526383` bytes (12.52 MB > 10 MB).
     - Header Magic: `PK` (`0x50 0x4B 0x03 0x04`).
     - SHA-256: `543A96FE26C012D99BAF3A3AA5A97B80508D67CC641AF7C12CE9F7B226B2B889` (verbatim match with `README_ROMS.md`).
     - Internal ZIP Entries: 1100 total entries; contains genuine 64-bit binaries:
       - `lib/arm64-v8a/libbusybox.so`
       - `lib/arm64-v8a/libmagisk64.so`
       - `lib/arm64-v8a/libmagiskboot.so`
       - `lib/arm64-v8a/libmagiskinit.so`
       - `lib/arm64-v8a/libmagiskpolicy.so`

### Observation 1.6: Non-Regression & Workspace Isolation
- **Command executed**: `git diff HEAD`
  - Output: Empty (0 modifications to tracked repository files).
- **Command executed**: `git status --porcelain bin drivers recovery roms stock_firmware begonia_tool.ps1 MENU_GENERAL.bat README.md README.fr.md`
  - Output: Empty. Zero Begonia files touched or modified.
- **Scope**: All modifications and created files reside strictly within `dandelion_tool/` and agent metadata directories.

---

## 2. Logic Chain

1. **Resolution of Iteration 1 Defects**:
   - In Iteration 1, Test `T1.6.4` crashed due to `$choice` variable expansion inside double quotes `"switch\s*\(\$choice\)"`, which produced an invalid regex and caused `ParameterBindingArgumentTransformationException`, silently dropping the test. Worker_2 converted this to single quotes `'switch\s*\(\$choice\)'`. Empirical execution of Tier 1 shows `T1.6.4` passes without throwing any exception, bringing Tier 1 to 38/38 passing tests (Observation 1.1).
   - In Iteration 1, Tier 2 standalone failed because `$romContent` was only initialized in Tier 1. Worker_2 added pre-flight content initialization in Section 0, making all content variables globally available regardless of which Tier is executed. Empirical execution of Tier 2 standalone yields 25/25 passing tests with exit code 0 (Observation 1.2).
   - The total test count is now exactly 74 tests registered and executed across all tiers (38 + 25 + 6 + 5 = 74) without any dropped or missing tests (Observation 1.3).

2. **Authenticity & Integrity Compliance**:
   - Under `ORIGINAL_REQUEST.md` (Demo Mode), facade implementations, hardcoded passes, and fabricated verification outputs are strictly prohibited.
   - Code inspection and automated scanning confirmed 0 occurrences of hardcoded `-Passed $true` in `test_dandelion.ps1` (Observation 1.4).
   - Scripts invoke real native tools (`adb.exe`, `fastboot.exe`, `mtk.py`, `msiexec.exe`) using relative paths from the workspace root (Observation 1.4).
   - Low-level byte analysis confirms authentic headers and structures for `vbmeta.img`, `recovery.img`, and `Magisk-v26.4.apk` (Observation 1.5).

3. **Workspace Isolation**:
   - `git diff HEAD` returns zero changes to tracked repository files, and Begonia root modules remain untouched, strictly fulfilling requirement R1 and the Non-Regression acceptance criteria (Observation 1.6).

4. **Conclusion of Cleanliness**:
   - Because all previously identified violations are fully remedied, all 74 tests pass cleanly, no cheats or facades exist, assets are authentic, and isolation is preserved, the work product satisfies all forensic integrity criteria.

---

## 3. Caveats

- **Physical Device**: Tests were conducted on a development workstation without a physical Xiaomi Redmi 10A handset connected. Validation of hardware interaction was verified through AST parsing, mocked/simulated command execution, real binary argument verification, and boundary tests (e.g., detecting missing fastboot device without hanging).
- **Scope Discipline**: Only `dandelion_tool/` and `.agents/teamwork/auditor_iter2_2/` were analyzed or executed.

---

## 4. Conclusion

**Verdict: CLEAN**

The work product `dandelion_tool/` complies with all requirements of `ORIGINAL_REQUEST.md` under Demo Mode. All Iteration 1 defects have been verified as resolved:
1. Test `T1.6.4` registers and executes cleanly with 0 exceptions.
2. Total test count is exactly 74 tests across all tiers (100% pass rate, exit code 0).
3. Tier 2 standalone execution (`run_tests.ps1 -Tier 2`) passes with exit code 0.
4. Assets (`vbmeta.img`, `recovery.img`, `Magisk-v26.4.apk`) are authentic.
5. Isolation and non-regression constraints are 100% satisfied (`git diff HEAD` is empty).

---

## 5. Verification Method

To independently reproduce this forensic audit:

1. **Verify Full Test Suite & Test Count (74/74 passed, exit code 0)**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All
   ```

2. **Verify Tier 2 Standalone Independence (25/25 passed, exit code 0)**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2
   ```

3. **Verify Zero ErrorRecords during Test Execution**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "$out = & 'dandelion_tool\tests\run_tests.ps1' -Tier All 2>&1; ($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count"
   ```
   *(Expected output: 0).*

4. **Verify Asset Magic & Flags**:
   ```powershell
   # vbmeta AVB0 and flag 0x02
   $vb = [System.IO.File]::ReadAllBytes('dandelion_tool\recovery\vbmeta.img')
   [System.Text.Encoding]::ASCII.GetString($vb, 0, 4) # Returns 'AVB0'
   [System.BitConverter]::ToUInt32($vb[123..120], 0).ToString('X8') # Returns '00000002'

   # recovery ANDROID! magic
   $rec = [System.IO.File]::ReadAllBytes('dandelion_tool\recovery\recovery.img')
   [System.Text.Encoding]::ASCII.GetString($rec, 0, 8) # Returns 'ANDROID!'

   # Magisk size and PK magic
   (Get-Item 'dandelion_tool\roms\Magisk-v26.4.apk').Length # Returns 12526383 (>10MB)
   ```

5. **Verify Non-Regression against Tracked Files**:
   ```cmd
   git diff HEAD
   ```
   *(Expected output: empty / 0 lines).*
