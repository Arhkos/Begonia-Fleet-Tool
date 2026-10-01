# Empirical Challenge Report & Verification Audit — `dandelion_tool/`

**Agent Identity:** challenger_2  
**Role:** Empirical Challenger (Critic / Specialist)  
**Date:** 2026-09-30T21:35:00Z  
**Verdict:** **REQUEST_CHANGES**

---

## 1. Observation

### Obs 1.1: Binary Artifact Byte-Level Verification
- **File:** `dandelion_tool\recovery\vbmeta.img`
  - Size: Exactly `4096` bytes.
  - Offset 0..3 Magic: `AVB0` (Hex: `41 56 42 30`).
  - Offset 4..11: Major version `1`, Minor version `0`.
  - Offset 120..123 (Flags Big-Endian uint32): `0x00000002` (Bit 1 `AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED` is True).
  - Offset 128..140 (Release string): `avbtool 1.1.0`.
  - SHA256: `F6DA5489FD877CB69CF61FA721CFD6D77E530084AEFE9B96664F818947FF61F6`.
- **File:** `dandelion_tool\recovery\recovery.img`
  - Size: `67108864` bytes (64.0 MB).
  - Offset 0..7 Magic: `ANDROID!` (Hex: `41 4E 44 52 4F 49 44 21`).
  - Header version: `2`. Kernel size: `11003407` bytes. Ramdisk size: `10874117` bytes. Page size: `2048` bytes.
  - Cmdline snippet: `bootopt=64S3,32N2,64N2 buildvariant=user systempart=/dev/mapper/`.
  - SHA256: `40B5EA262E08BE110302C8F73EEC8DCF16ACC051BE54217735D5DED5B3172DA9`.
- **File:** `dandelion_tool\roms\Magisk-v26.4.apk`
  - Size: `12526383` bytes (11.95 MB).
  - Header Magic: `50 4B 03 04` (Valid ZIP PK format).
  - Archive contents inspected via `[System.IO.Compression.ZipFile]`:
    - `classes.dex` present (2488992 bytes).
    - `lib/arm64-v8a/libbusybox.so` (2149248 bytes).
    - `lib/arm64-v8a/libmagisk64.so` (298648 bytes).
    - `lib/arm64-v8a/libmagiskboot.so` (1206976 bytes).
    - `lib/arm64-v8a/libmagiskinit.so` (693320 bytes).
    - `lib/arm64-v8a/libmagiskpolicy.so` (345576 bytes).
  - SHA256: `543A96FE26C012D99BAF3A3AA5A97B80508D67CC641AF7C12CE9F7B226B2B889`.

### Obs 1.2: ADB Verification Logic & Regex Adversarial Testing
- **Architecture Check Logic (`ro.product.cpu.abi`):**
  - Implemented in `dandelion_tool.ps1:243` (`$abi -eq "arm64-v8a"`) and `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:110` (`if /i "%CURRENT_ABI%"=="arm64-v8a"`).
  - Adversarial matrix tested across 10 test vectors:
    - `"arm64-v8a"`, `"arm64-v8a\r\n"`, `"  arm64-v8a  "`: **PASS** (accepted).
    - `"armeabi-v7a"`, `"armeabi-v7a\r\n"`, `"armeabi"`, `"arm64"`, `"arm64-v8a-variant"`, `""`, `"x86_64"`: **STRICTLY REJECTED**.
- **Root Check Logic (`su -c "id"`):**
  - Implemented in `dandelion_tool.ps1:256` (`$rootOutput -match "uid=0\(root\)"`) and `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:123` (`echo %ROOT_OUTPUT% | findstr /c:"uid=0(root)"`).
  - Adversarial matrix tested across 10 test vectors:
    - `"uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0"`: **PASS** (accepted).
    - `"uid=0(root) gid=0(root) groups=0(root)"`: **PASS** (accepted).
    - `"uid=2000(shell) gid=2000(shell)"`, `"/system/bin/sh: su: not found"`, `"/system/bin/sh: su: inaccessible or not found"`, `"Permission denied"`, `"uid=1000(system)"`, `"uid=00(root)"`, `"uid=0(rootfake)"`, `""`: **STRICTLY REJECTED**.
  - 0 false positives, 0 false negatives across both PowerShell and CMD pipelines.

### Obs 1.3: Fastboot Flag Placement Audit
Every occurrence of `fastboot.exe` with AVB flags was audited:
- `1_FLASHER_RECOVERY_ET_VBMETA.bat:32`:
  `"%~dp0..\bin\fastboot.exe" --disable-verity --disable-verification flash vbmeta "%~dp0recovery\vbmeta.img"`
- `dandelion_tool.ps1:163`:
  `& "$fastbootExe" --disable-verity --disable-verification flash vbmeta "$vbmetaImg"`
- `README.md:105`:
  `..\bin\fastboot.exe --disable-verity --disable-verification flash vbmeta "recovery\vbmeta.img"`
- In 100% of occurrences, `--disable-verity` and `--disable-verification` precede `flash vbmeta`. Zero misplaced flags found.

### Obs 1.4: Strict Non-Regression Audit
- Executed `git status --porcelain`:
  ```
  ?? .agents/
  ?? dandelion_tool/
  ?? hwparam.json
  ?? src/mtkclient/
  ```
- Executed `git diff --stat HEAD`: returned zero modified lines / zero modified files.
- `hwparam.json` and `src/mtkclient/` date back to 23/08/2026 (pre-existing repo assets).
- ZERO files belonging to the Begonia codebase outside `dandelion_tool/` have been altered.

### Obs 1.5: Test Suite Defects Discovered Empirically
1. **Defect 1 — Runtime Regex Parser Exception in `test_dandelion.ps1:348`:**
   - Command: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All`
   - Output observed verbatim during Tier 1 execution:
     ```
     analyse de "switch\s*\(\\)" - Trop de ).
     Au caractre C:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1:348 : 5
     +     $hasMenuOptions = ($ps1Content -match "switch\s*\(\$choice\)" -or ...
     +     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
         + CategoryInfo          : OperationStopped: (:) [], ArgumentException
         + FullyQualifiedErrorId : System.ArgumentException
      
     Register-TestResult : Impossible de traiter la transformation d'argument sur le paramtre Passed. Impossible de 
     convertir la valeur  en type System.Boolean. Les paramtres boolens acceptent seulement des valeurs boolennes et 
     des nombres, tels que $True, $False, 1 ou 0.
     Au caractre C:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\tests\test_dandelion.ps1:350 : 133
     + ... l interactive menu lifecycle options" -Passed $hasMenuOptions -Detail ...
     +                                                   ~~~~~~~~~~~~~~~
         + CategoryInfo          : InvalidData : (:) [Register-TestResult], ParameterBindingArgumentTransformationException
         + FullyQualifiedErrorId : ParameterArgumentTransformationError,Register-TestResult
     ```
   - **Consequence:** In double quotes, PowerShell attempts variable interpolation on `$choice`, expanding it to empty string `$null` because `\$` is not a dollar escape in PowerShell (backtick `` `$ `` is). The regex becomes `switch\s*\(\)` (missing closing parenthesis), throwing `System.ArgumentException`. Test `T1.6.4` is skipped, registering only 37 tests in Tier 1 instead of 38.

2. **Defect 2 — Independent Execution Failure of Tier 2 (`-Tier 2`):**
   - Command: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2`
   - Output observed verbatim:
     ```
     ================================================================================
       [Tier 2] Boundary Group 3: Exit Code Propagation
     ================================================================================
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
     Exit code: 1
     ```
   - **Root Cause:** In `test_dandelion.ps1:474`, Test `T2.3.2` checks:
     `$noSilentExit = ($unlockContent -match "pause" -and $recContent -match "pause" -and $romContent -match "pause")`
     However, `$unlockContent`, `$recContent`, and `$romContent` are defined on lines 219, 251, and 285 inside `if ($Tier -in @("1", "All")) { ... }`. When the test suite is launched with `-Tier 2`, these variables are uninitialized (`$null`), causing `$null -match "pause"` to evaluate to `$false`, triggering a test failure and returning exit code 1!

---

## 2. Logic Chain

1. **Premise:** The requirements in `ORIGINAL_REQUEST.md` (R1 to R5) and acceptance criteria mandate that `dandelion_tool/` provides valid artifacts, safe scripts, isolated execution, and an automated verification test suite.
2. **Step 1 (Artifacts & Non-Regression):** Observations 1.1, 1.2, 1.3, and 1.4 confirm that `vbmeta.img`, `recovery.img`, and `Magisk-v26.4.apk` are completely valid and conform to AVB 2.0, Android Boot Header v2, and APK/ZIP standards. The architecture and root check logic are verified across all edge cases. The fastboot flag placement is correct. Zero external files were touched.
3. **Step 2 (Test Suite Contract):** The test runner `run_tests.ps1` explicitly exposes `-Tier <1|2|3|4|All>` as a parameter contract. Users and CI pipelines running isolated tiers expect independent execution and clean exit codes.
4. **Step 3 (Obs 1.5 Defect 1 Impact):** At line 348 of `test_dandelion.ps1`, using `"switch\s*\(\$choice\)"` in double quotes triggers a .NET regex parsing exception because PowerShell evaluates `$choice` as null. This causes test assertion `T1.6.4` to fail registration.
5. **Step 4 (Obs 1.5 Defect 2 Impact):** At line 474 of `test_dandelion.ps1`, scoping variables `$unlockContent`, `$recContent`, and `$romContent` inside the `Tier 1` conditional block causes `run_tests.ps1 -Tier 2` to fail with exit code 1 due to null reference matching.
6. **Inference:** Because an adversarial challenger must verify robustness and find latent defects in both scripts and test harnesses, shipping broken tier execution (`-Tier 2` failing with exit code 1) and an unhandled regex syntax error violates software test integrity.

---

## 3. Caveats

- **Hardware Execution:** Tests were performed via byte inspection, static AST analysis, argument parser validation, and simulated device responses; physical USB execution against a live MT6762G handset was not performed as no physical device is attached to the host.
- **Scope of Review:** In accordance with key constraints, no modifications were made to implementation or test code. Remediation must be applied by the designated worker or test writer agent.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES**

The core scripts, binary images, APK assets, and non-regression guarantees of `dandelion_tool/` are sound, robust, and exceed requirements. However, **2 concrete defects** in `dandelion_tool\tests\test_dandelion.ps1` must be remediated:

### Required Remediations:
1. **Fix Line 348 Regex in `dandelion_tool\tests\test_dandelion.ps1`:**
   Change:
   ```powershell
   $hasMenuOptions = ($ps1Content -match "switch\s*\(\$choice\)" -or $ps1Content -match "Show-Menu") -and 
   ```
   To:
   ```powershell
   $hasMenuOptions = ($ps1Content -match 'switch\s*\(\$choice\)' -or $ps1Content -match "Show-Menu") -and 
   ```
   (Use single quotes so `$choice` is not evaluated as a variable by PowerShell).

2. **Fix Cross-Tier Variable Scoping for Tier 2 in `dandelion_tool\tests\test_dandelion.ps1`:**
   In Section 0 (lines 33-36) or immediately before Tier 2, ensure `$unlockContent`, `$recContent`, and `$romContent` are loaded globally or initialized independently:
   ```powershell
   $unlockContent = if (Test-Path "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat") { Get-Content "$ToolDir\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat" -Raw -Encoding UTF8 } else { "" }
   $recContent    = if (Test-Path "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat") { Get-Content "$ToolDir\1_FLASHER_RECOVERY_ET_VBMETA.bat" -Raw -Encoding UTF8 } else { "" }
   $romContent    = if (Test-Path "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat") { Get-Content "$ToolDir\2_INSTALLER_ROM_64BIT_ET_ROOT.bat" -Raw -Encoding UTF8 } else { "" }
   ```

---

## 5. Verification Method

To verify the defects and validate their resolution once patched:

1. **Reproduce Defect 1 (Line 348 Regex Exception & Missing T1.6.4):**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 1
   ```
   *Expected defect behavior:* Throws `ArgumentException: switch\s*\(\) - Trop de )` and skips `T1.6.4`.
   *Target resolution behavior:* Zero regex errors, 38/38 tests passing in Tier 1.

2. **Reproduce Defect 2 (Tier 2 Isolation Failure):**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2
   ```
   *Expected defect behavior:* Fails on `T2.3.2`, exits with code 1.
   *Target resolution behavior:* 25/25 tests passing in Tier 2, exit code 0.

3. **Verify Full Suite Across All Tiers:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All
   ```
   *Target resolution behavior:* 74/74 tests passing (38 in T1, 25 in T2, 6 in T3, 5 in T4), exit code 0.
