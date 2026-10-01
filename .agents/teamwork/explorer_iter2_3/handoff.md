# PowerShell Fleet Tool Hardening Strategy Report — `dandelion_tool.ps1`

**Subagent**: `explorer_iter2_3` (Explorer / Strategy Formulator)  
**Parent Agent**: `4042be46-bc7d-49fd-b893-c25553514f78` (Orchestrator)  
**Target File**: `c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\dandelion_tool.ps1`  
**Milestone**: Iteration 2 — PowerShell Fleet Tool Hardening & Resilience  
**Date**: 2026-09-30T21:40:00Z  

---

## 1. Observation

### Observation 1.1: Parameter Routing & Non-Interactive Invocations Flaw
- **File**: `dandelion_tool\dandelion_tool.ps1`
- **Lines 7-9 & 294-306**:
  ```powershell
  7: param (
  8:     [string]$Action = "menu"
  9: )
  ...
  294: # Routage des actions selon le parametre $Action
  295: switch ($Action.ToLower()) {
  296:     "menu"           { Show-Menu }
  297:     "check"          { Check-Environment }
  298:     "env"            { Check-Environment }
  299:     "install-usbdk"  { Install-UsbDk-Driver }
  300:     "unlock"         { Unlock-And-FRP }
  301:     "recovery"       { Flash-Recovery-Fastboot }
  302:     "deploy-rom"     { Push-ROM-Files-ADB }
  303:     "verify"         { Verify-System-ADB }
  304:     Default          { Show-Menu }
  305: }
  ```
- **Behavior Observed**:
  When invoked non-interactively with an invalid or unexpected action (e.g., `-Action invalid_param`), the switch router executes `Default { Show-Menu }`.
  Inside `Show-Menu`:
  ```powershell
  267:         Show-Header
  268:         Check-Environment
  ...
  280:         $choice = Read-Host "Selectionnez une option (1-6)"
  ```
  The script clears the console and indefinitely hangs awaiting standard input on `Read-Host`. In headless environments, automated CI test harnesses, or subagent tasks, this creates an unrecoverable process freeze (as documented in `challenger_1/handoff.md:94` where task-44 had to be killed).
  Furthermore, if `-Action $null` is passed, `$Action.ToLower()` throws an unhandled `NullReferenceException` (`You cannot call a method on a null-valued expression`).

### Observation 1.2: Fastboot Device Presence Verification Flaw
- **File**: `dandelion_tool\dandelion_tool.ps1`
- **Lines 155-161**:
  ```powershell
  155:     Write-Host "[*] Verification de la presence du peripherique Fastboot..." -ForegroundColor Yellow
  156:     & "$fastbootExe" devices
  157:     if ($LASTEXITCODE -ne 0) {
  158:         Write-Host "[-] Erreur d'execution de fastboot.exe." -ForegroundColor Red
  159:         return
  160:     }
  161: 
  162:     Write-Host "[*] Flash de vbmeta.img avec desactivation AVB 2.0 (dm-verity)..." -ForegroundColor Yellow
  163:     & "$fastbootExe" --disable-verity --disable-verification flash vbmeta "$vbmetaImg"
  ```
- **Behavior Observed**:
  `fastboot devices` returns exit code 0 (`$LASTEXITCODE = 0`) even when zero devices are connected to the host system. The output is simply empty string `""`.
  Because `$LASTEXITCODE -ne 0` evaluates to `$false`, execution immediately proceeds to line 163:
  `& "$fastbootExe" --disable-verity --disable-verification flash vbmeta "$vbmetaImg"`
  Fastboot flash commands without a connected device hang indefinitely in the console with `< waiting for any device >`, freezing unattended scripts and blocking technicians without an explicit diagnostic message.

### Observation 1.3: Missing Error Logging for Magisk Push Failure
- **File**: `dandelion_tool\dandelion_tool.ps1`
- **Lines 210-217**:
  ```powershell
  210:     # Envoi de Magisk pour le root
  211:     if (Test-Path $magiskApk) {
  212:         Write-Host "[*] Envoi de Magisk v26.4 vers /sdcard/Magisk-v26.4.zip ..." -ForegroundColor Yellow
  213:         & "$adbExe" push "$magiskApk" /sdcard/Magisk-v26.4.zip
  214:         if ($LASTEXITCODE -eq 0) {
  215:             Write-Host "[+] Magisk-v26.4.zip pret pour installation dans le recovery !" -ForegroundColor Green
  216:         }
  217:     }
  ```
- **Behavior Observed**:
  In `Push-ROM-Files-ADB`, while the preceding ROM loop has error handling for `$LASTEXITCODE -ne 0` (lines 203-205), the Magisk push step only evaluates `if ($LASTEXITCODE -eq 0)`.
  If `adb push` encounters a socket failure, permission error, or device disconnection (`$LASTEXITCODE -ne 0`), there is no `else` block. The failure is silently swallowed without logging an error tag `[-]`.
  Additionally, if `Test-Path $magiskApk` is false, no error tag `[-]` is logged to inform the technician of the missing payload file.

### Observation 1.4: Overall AST and String Trimming Robustness
- **PowerShell AST Parser**:
  Running `[System.Management.Automation.Language.Parser]::ParseFile('dandelion_tool\dandelion_tool.ps1', [ref]$null, [ref]$null)` succeeds with 0 syntax errors.
- **Potential Runtime Edge Case in `Verify-System-ADB`**:
  Lines 240 and 253:
  ```powershell
  240:     $abi = (& "$adbExe" shell getprop ro.product.cpu.abi).Trim()
  ...
  253:     $rootOutput = (& "$adbExe" shell su -c "id" 2>&1).Trim()
  ```
  If `adb.exe` fails to start or produces `$null`, invoking method `.Trim()` on `$null` throws a runtime exception: `You cannot call a method on a null-valued expression.` Piping through `Out-String` before `.Trim()` guarantees null-safety.

---

## 2. Logic Chain

1. **Parameter Routing and Script Non-Interactivity**:
   - *Premise*: Tool scripts in a multi-agent or enterprise fleet environment must support automated execution via CLI parameters as well as interactive menus.
   - *Deduction from Obs 1.1*: When a user or automated test passes an invalid parameter (`-Action invalid_param`), falling back to `Show-Menu` triggers `Read-Host`. In non-interactive contexts, this causes an infinite hang.
   - *Resolution*: The `Default` branch of the root switch router must not invoke `Show-Menu`. Instead, it must print an explicit error tag `[-]` detailing the invalid action and valid alternatives, then terminate the process with `exit 1`. Furthermore, normalizing `$Action` safely handles null or empty inputs.

2. **Fastboot Device Presence Detection**:
   - *Premise*: Flashing recovery or partition images must only occur when a target handset is confirmed present in Fastboot mode.
   - *Deduction from Obs 1.2*: Relying solely on `$LASTEXITCODE` of `fastboot devices` is defective because `fastboot.exe` returns 0 when device output is empty.
   - *Resolution*: Capture the stdout/stderr of `fastboot devices`, check `$LASTEXITCODE`, and test if the resulting string is null or whitespace (`[string]::IsNullOrWhiteSpace($fbDevices)`). If empty, display an explicit warning `[-]` and return cleanly, preventing the `< waiting for any device >` hang.

3. **ADB Push Error Visibility**:
   - *Premise*: Fleet installation of root packages requires unambiguous status reporting so automated testers and technicians know whether Magisk was transferred.
   - *Deduction from Obs 1.3*: The absence of an `else` branch for Magisk `adb push` failure means a broken transfer is indistinguishable from a skipped step, violating standard error reporting.
   - *Resolution*: Add an explicit `else` branch logging `[-] ERREUR lors de l'envoi de Magisk-v26.4.apk (code $LASTEXITCODE).` in Red. Also add an `else` branch for `Test-Path $magiskApk` logging `[-] Fichier Magisk introuvable : $magiskApk`.

4. **PowerShell AST & Syntactic Conformance**:
   - *Premise*: All modifications must strictly preserve PowerShell AST validity, conform to `test_dandelion.ps1` regex checks, and maintain Begonia visual styling standards (`Cyan`, `Yellow`, `Green`, `Red`).
   - *Deduction*: By verifying the AST via `[System.Management.Automation.Language.Parser]` and matching existing test patterns (`Test-Path`, `$LASTEXITCODE -ne 0`, `flash vbmeta`, `Show-Menu`), the hardened script will remain 100% backward compatible while satisfying all new resilience criteria.

---

## 3. Concrete Remediation Strategy (Diff & Implementation Guide)

The following changes must be applied to `dandelion_tool\dandelion_tool.ps1`:

### Change 1: Fastboot Device Presence Verification in `Flash-Recovery-Fastboot`

**Target Location**: `dandelion_tool\dandelion_tool.ps1` lines 155–161

**Before**:
```powershell
    Write-Host "[*] Verification de la presence du peripherique Fastboot..." -ForegroundColor Yellow
    & "$fastbootExe" devices
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] Erreur d'execution de fastboot.exe." -ForegroundColor Red
        return
    }
```

**After**:
```powershell
    Write-Host "[*] Verification de la presence du peripherique Fastboot..." -ForegroundColor Yellow
    $fbRaw = & "$fastbootExe" devices 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] Erreur d'execution de fastboot.exe." -ForegroundColor Red
        return
    }

    $fbDevices = ($fbRaw | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($fbDevices)) {
        Write-Host "[-] Aucun peripherique Fastboot detecte ! Connectez le telephone en mode Fastboot (VOLUME BAS + POWER)." -ForegroundColor Red
        return
    }
    Write-Host "[+] Peripherique Fastboot detecte :" -ForegroundColor Green
    Write-Host "    $fbDevices" -ForegroundColor Cyan
```

---

### Change 2: Error Logging in ADB Push for `Push-ROM-Files-ADB`

**Target Location**: `dandelion_tool\dandelion_tool.ps1` lines 210–217

**Before**:
```powershell
    # Envoi de Magisk pour le root
    if (Test-Path $magiskApk) {
        Write-Host "[*] Envoi de Magisk v26.4 vers /sdcard/Magisk-v26.4.zip ..." -ForegroundColor Yellow
        & "$adbExe" push "$magiskApk" /sdcard/Magisk-v26.4.zip
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Magisk-v26.4.zip pret pour installation dans le recovery !" -ForegroundColor Green
        }
    }
```

**After**:
```powershell
    # Envoi de Magisk pour le root
    if (Test-Path $magiskApk) {
        Write-Host "[*] Envoi de Magisk v26.4 vers /sdcard/Magisk-v26.4.zip ..." -ForegroundColor Yellow
        & "$adbExe" push "$magiskApk" /sdcard/Magisk-v26.4.zip
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Magisk-v26.4.zip pret pour installation dans le recovery !" -ForegroundColor Green
        } else {
            Write-Host "[-] ERREUR lors de l'envoi de Magisk-v26.4.apk (code $LASTEXITCODE)." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Fichier Magisk introuvable : $magiskApk" -ForegroundColor Red
    }
```

---

### Change 3: Defense-in-Depth Null-Safe Trimming in `Verify-System-ADB`

**Target Location**: `dandelion_tool\dandelion_tool.ps1` lines 240 and 253

**Before**:
```powershell
240:     $abi = (& "$adbExe" shell getprop ro.product.cpu.abi).Trim()
...
253:     $rootOutput = (& "$adbExe" shell su -c "id" 2>&1).Trim()
```

**After**:
```powershell
    $abiRaw = & "$adbExe" shell getprop ro.product.cpu.abi 2>&1
    $abi = ($abiRaw | Out-String).Trim()
...
    $rootRaw = & "$adbExe" shell su -c "id" 2>&1
    $rootOutput = ($rootRaw | Out-String).Trim()
```

---

### Change 4: Hardened Parameter Routing & Invalid Action Handling

**Target Location**: `dandelion_tool\dandelion_tool.ps1` lines 294–306

**Before**:
```powershell
# Routage des actions selon le parametre $Action
switch ($Action.ToLower()) {
    "menu"           { Show-Menu }
    "check"          { Check-Environment }
    "env"            { Check-Environment }
    "install-usbdk"  { Install-UsbDk-Driver }
    "unlock"         { Unlock-And-FRP }
    "recovery"       { Flash-Recovery-Fastboot }
    "deploy-rom"     { Push-ROM-Files-ADB }
    "verify"         { Verify-System-ADB }
    Default          { Show-Menu }
}
```

**After**:
```powershell
# Routage des actions selon le parametre $Action
$actionNorm = if ([string]::IsNullOrWhiteSpace($Action)) { "menu" } else { $Action.Trim().ToLower() }
switch ($actionNorm) {
    "menu"           { Show-Menu }
    "check"          { Check-Environment }
    "env"            { Check-Environment }
    "install-usbdk"  { Install-UsbDk-Driver }
    "unlock"         { Unlock-And-FRP }
    "recovery"       { Flash-Recovery-Fastboot }
    "deploy-rom"     { Push-ROM-Files-ADB }
    "verify"         { Verify-System-ADB }
    Default {
        Write-Host "[-] Action invalide : '$Action'. Actions valides : menu, check, env, install-usbdk, unlock, recovery, deploy-rom, verify." -ForegroundColor Red
        exit 1
    }
}
```

---

## 4. Caveats

- **Scope Boundary**: In accordance with the Explorer archetype read-only mandate, this agent has NOT directly overwritten `dandelion_tool.ps1`. The exact patch and line ranges are provided for `worker_1` (or the designated implementer agent) to apply.
- **Interactive Stdin in Manual Actions**: Functions `Unlock-And-FRP`, `Flash-Recovery-Fastboot`, and `Push-ROM-Files-ADB` still contain deliberate `Read-Host "Appuyez sur Entree..."` prompts for guided operator interaction. When invoking `dandelion_tool.ps1` in unattended test scripts, tests should pass `-Action check`, mock inputs, or execute isolated functions rather than invoking hardware flashing interactively.
- **Device Hardware**: Testing of Fastboot and ADB output checks was simulated without live MT6762G hardware connected.

---

## 5. Conclusion

The PowerShell fleet tool `dandelion_tool\dandelion_tool.ps1` is structurally well-designed and satisfies all Begonia project conventions, but required hardening in four specific areas:
1. **Parameter Routing**: Terminate with `[-] Action invalide...` and `exit 1` instead of hanging on `Read-Host` in `Default`.
2. **Fastboot Presence**: Check that `fastboot devices` stdout is non-empty before flashing `vbmeta.img` or `recovery.img` to avoid `< waiting for any device >` freezes.
3. **Magisk Push Error Logging**: Provide explicit `else` error logging with `[-]` for `adb push` non-zero exit codes and missing APK files.
4. **AST & Null Robustness**: Null-safe command trimming via `Out-String` and 100% AST parse compliance.

Applying the four concrete changes detailed in Section 3 eliminates all identified failure modes, prevents automated hangs, and ensures full compatibility with both the existing test suite and new hardening checks.

---

## 6. Verification Method

Once the changes are implemented in `dandelion_tool\dandelion_tool.ps1`:

1. **Verify Invalid Action Handling (Non-Interactive Error & Exit Code 1)**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'dandelion_tool\dandelion_tool.ps1' -Action invalid_param; exit `$LASTEXITCODE"
   ```
   *Expected Result*: Exits immediately with exit code `1`. Output includes `[-] Action invalide : 'invalid_param'`. Does NOT clear the screen or hang on `Read-Host`.

2. **Verify Valid Action Handling Without Prompts**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'dandelion_tool\dandelion_tool.ps1' -Action check; exit `$LASTEXITCODE"
   ```
   *Expected Result*: Prints environment diagnostics and exits cleanly with exit code `0`.

3. **Verify AST Conformance & Zero Parser Errors**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "$ast = [System.Management.Automation.Language.Parser]::ParseFile('dandelion_tool\dandelion_tool.ps1', [ref]`$null, [ref]`$null); if (`$ast) { 'AST OK' }"
   ```
   *Expected Result*: Returns `AST OK` with 0 errors.

4. **Verify Existing E2E Suite Compatibility**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All
   ```
   *Expected Result*: All existing tests continue to pass without regression.
