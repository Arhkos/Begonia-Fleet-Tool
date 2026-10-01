## 2026-09-30T21:44:49Z
You are worker_2, an implementation specialist subagent.
Your working directory is: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\worker_2\
The verbatim original user request is located at: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\ORIGINAL_REQUEST.md
You MUST read c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\ORIGINAL_REQUEST.md before starting work.

Also read:
- Test Suite Remediation Strategy: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\explorer_iter2_1\handoff.md
- Batch Script Hardening Strategy: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\explorer_iter2_2\handoff.md
- PowerShell Hardening Strategy: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\explorer_iter2_3\handoff.md
- Auditor Evidence Report: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\auditor_1\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

CRITICAL NON-REGRESSION CONSTRAINT:
You have EXCLUSIVE write ownership of `c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\`.
You MUST NOT modify or touch ANY file outside `dandelion_tool/`. All existing files at repository root and in `recovery/`, `roms/`, `stock_firmware/`, `src/`, `bin/`, `drivers/` MUST remain 100% untouched.

Objective & Deliverables:
Implement the complete hardening and remediation fixes across `dandelion_tool/` following the exact specifications from the 3 explorers:

1. `dandelion_tool\tests\test_dandelion.ps1`:
   - Section 0 (lines 33-36): Add the canonical common script paths and global pre-flight content initialization for `$unlockContent`, `$recContent`, `$romContent`, `$ps1Content`, and `$readmeContent`.
   - Line 348 (Test T1.6.4): Fix the regex escaping by using single quotes:
     `$hasMenuOptions = ($ps1Content -match 'switch\s*\(\$choice\)' -or $ps1Content -match "Show-Menu") -and ...`
     This eliminates the `System.ArgumentException` and ensures all 38 tests in Tier 1 register and pass cleanly.
   - Tier 2 (after line 431 / after Test 2.1.4): Add local initialization for `$romContent` so running `run_tests.ps1 -Tier 2` standalone has zero dependencies on Tier 1 and passes with exit code 0.

2. `dandelion_tool\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`:
   - Line 35: Fix the UsbDk installer quoting and exit code handling under `Start-Process msiexec`:
     ```cmd
     set "USBDK_MSI=%~dp0..\drivers\UsbDk_1.0.22_x64.msi"
     powershell -NoProfile -Command "$proc = Start-Process msiexec.exe -ArgumentList '/i', ('\"' + $env:USBDK_MSI + '\"') -Verb RunAs -Wait -PassThru; exit $proc.ExitCode"
     ```
   - Lines 65-88: Preserve `%errorlevel%` on exit when mtkclient fails by setting `set EXIT_CODE=%errorlevel%` and checking `if %EXIT_CODE% neq 0 exit /b %EXIT_CODE%` after `pause`.

3. `dandelion_tool\1_FLASHER_RECOVERY_ET_VBMETA.bat`:
   - Lines 18-26: Handle empty `fastboot devices` output using a `for /f` loop. If empty, print an explicit error banner and exit with code 1 after pause. Do NOT hang on `< waiting for any device >`. Also include codename safety check (`fastboot getvar product`).

4. `dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`:
   - Line 49: Quote ROM filename in echo: `echo [*] Copie de la ROM detectee : "%%~nxf" ...`.
   - Line 120: Avoid multi-quote stripping in CMD `for /f` by prepending `call` and using `su -c id`:
     `for /f "tokens=*" %%b in ('call "%~dp0..\bin\adb.exe" shell su -c id 2^>nul') do set ROOT_OUTPUT=%%b`
   - Line 123: Quote `"%ROOT_OUTPUT%"` in `findstr`:
     `echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul`
     This prevents fatal `<stdin>` file redirection crashes when `su` is missing.

5. `dandelion_tool\MENU_DANDELION.bat`:
   - Add `chcp 65001 >nul` at line 2.

6. `dandelion_tool\dandelion_tool.ps1`:
   - Parameter routing: Normalize `$Action`. In `Default`, print an explicit error message `[-] Action invalide : '$Action' ...` and terminate with `exit 1` instead of falling back to `Show-Menu` and hanging on `Read-Host`.
   - Fastboot presence: In `Flash-Recovery-Fastboot`, check that `fastboot devices` output is non-empty before executing flash commands. If empty, warn and return cleanly.
   - ADB push error handling: In `Push-ROM-Files-ADB`, add an explicit `else` block to log an error tag `[-]` if Magisk push fails (`$LASTEXITCODE -ne 0`) or if the APK is missing.
   - Trimming: Ensure null-safe trimming with `Out-String` in `Verify-System-ADB`.

Verification:
- Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 1` (must pass 38/38, 0 exceptions, exit code 0).
- Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 2` (must pass 25/25, exit code 0).
- Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 3` (must pass 6/6, exit code 0).
- Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier 4` (must pass 5/5, exit code 0).
- Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All` (must pass 74/74, exit code 0).
- Test: `powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\dandelion_tool.ps1" -Action invalid_param` (must exit with code 1 immediately without hanging).
- Run: `git status --porcelain` (must show zero modified files outside `dandelion_tool/`).

Document all verification commands and outputs in `c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\worker_2\handoff.md`.
Send a completion message via `send_message`.
