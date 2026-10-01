# Batch Scripts Hardening Strategy Report — `dandelion_tool/`

**Agent Identity:** `explorer_iter2_2`  
**Role:** Explorer & Strategy Specialist  
**Parent Agent:** `4042be46-bc7d-49fd-b893-c25553514f78`  
**Working Directory:** `c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\explorer_iter2_2\`  
**Date:** 2026-09-30T21:45:00Z  

---

## Executive Summary

This report delivers the complete forensic analysis and exact remediation strategy for all batch scripts in `dandelion_tool/`:
1. `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat:35`: Resolution of the UsbDk installer path quoting bug under PowerShell `Start-Process msiexec.exe`, ensuring correct handling of paths containing spaces and preserving child process exit codes and `%errorlevel%` on script exit.
2. `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:120`: Resolution of CMD `for /f` multi-quote stripping on workspace paths with spaces when invoking `adb.exe shell su -c id`.
3. `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:123`: Quoting `%ROOT_OUTPUT%` during `echo ... | findstr` to prevent fatal `<stdin>` file redirection crashes when `su` is missing or prints `/system/bin/sh: <stdin>[1]: su: not found`.
4. `1_FLASHER_RECOVERY_ET_VBMETA.bat:19`: Reliable capture and detection of empty `fastboot devices` output to eliminate indefinite hangs on `< waiting for any device >` when no device is attached, plus optional codename validation.
5. `MENU_DANDELION.bat:2`: Addition of `chcp 65001 >nul` at line 2 per `PROJECT.md` contract.

All proposed syntax variants were empirically tested against the Win32 C runtime argument parser, CMD subshell quote stripper, and PowerShell host.

---

## 1. Observation

### Observation 1.1: UsbDk Installer Quoting and Exit Code Propagation in `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`
- **Location:** `dandelion_tool\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`, lines 34–36 and lines 67–88.
- **Current Code (lines 34–36):**
  ```cmd
  echo [*] Elevation des privileges Administrateur pour UsbDk...
  powershell -NoProfile -Command "Start-Process msiexec.exe -ArgumentList '/i', '\"%~dp0..\drivers\UsbDk_1.0.22_x64.msi\"' -Verb RunAs -Wait"
  ```
- **Empirical Test:**
  When passing `'\"%~dp0...\UsbDk_1.0.22_x64.msi\"'` inside `powershell -Command "..."`:
  In PowerShell, single quotes `'...'` are literal strings; `\"` is parsed as a literal backslash followed by a quote. When `Start-Process` receives `'/i'` and `'\"C:\...\UsbDk...msi\"'` in `-ArgumentList` as an array, it attempts to escape and wrap the token containing spaces for Win32 `CreateProcess`.
  Testing argument extraction with Python C-runtime parser (`sys.argv`):
  ```
  powershell -NoProfile -Command "Start-Process msiexec.exe -ArgumentList '/i', '\"%~dp0..\drivers\UsbDk_1.0.22_x64.msi\"' -Verb RunAs -Wait"
  ```
  Resulting Win32 argument parsed by the child process:
  ```
  ARG1=[/i]
  ARG2=[ " C:\Program Files\Test Path\installer.msi\ ]
  ```
  `msiexec.exe` receives a leading space and trailing backslash inside the path parameter, failing immediately with a path syntax error.
  Furthermore, `Start-Process` without `-PassThru; exit $proc.ExitCode` discards the installer's exit code, always returning 0 from PowerShell.
- **Current Exit Handling (lines 67–88):**
  ```cmd
  python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"

  if %errorlevel% neq 0 (
      echo [-] ERREUR CRITIQUE : L'operation mtkclient a echoue (code %errorlevel%).
      ...
  ) else (
      ...
  )
  pause
  ```
  When `mtkclient` fails (`%errorlevel% neq 0`), the script echoes the failure banner, but then executes `pause` and terminates. Because `pause` returns 0, the script exits with code 0 instead of propagating the failure exit code.

---

### Observation 1.2: CMD `for /f` Multi-Quote Stripping in `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:120`
- **Location:** `dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`, line 120.
- **Current Code:**
  ```cmd
  set ROOT_OUTPUT=non_defini
  for /f "tokens=*" %%b in ('"%~dp0..\bin\adb.exe" shell su -c "id" 2^>nul') do set ROOT_OUTPUT=%%b
  ```
- **Empirical Test:**
  When `%~dp0` contains spaces (e.g. `C:\Users\Arhkos\AppData\Local\Temp\dandelion test space\dandelion_tool\`), the command string passed to `cmd /c` contains four quote characters (`"%~dp0...\adb.exe"` and `"id"`).
  Under CMD's quote processing rules (`cmd /?`): if a command line passed to `cmd /c` has more than two quote characters and begins with a quote, CMD unconditionally strips the first quote and the last quote.
  The command executed by CMD becomes:
  ```
  C:\Users\Arhkos\AppData\Local\Temp\dandelion test space\...\bin\adb.exe" shell su -c "id
  ```
  CMD attempts to execute `C:\Users\Arhkos\AppData\Local\Temp\dandelion`, emitting:
  ```
  'C:\Users\Arhkos\AppData\Local\Temp\dandelion' n'est pas reconnu en tant que commande interne ou externe
  ```
  Because `2^>nul` suppresses stderr, the error is silenced. `%ROOT_OUTPUT%` remains `"non_defini"`, causing false failure of the root verification check.

---

### Observation 1.3: `<stdin>` Input Redirection Crash in `2_INSTALLER_ROM_64BIT_ET_ROOT.bat:123`
- **Location:** `dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`, lines 122–124.
- **Current Code:**
  ```cmd
  echo     Reponse de la commande : %ROOT_OUTPUT%
  echo %ROOT_OUTPUT% | findstr /c:"uid=0(root)" >nul
  ```
- **Empirical Test:**
  When `su` is missing or access is not yet authorized in Magisk, Android's `/system/bin/sh` outputs:
  ```
  /system/bin/sh: <stdin>[1]: su: not found
  ```
  Piping `%ROOT_OUTPUT%` unquoted into `findstr`:
  ```cmd
  echo /system/bin/sh: <stdin>[1]: su: not found | findstr /c:"uid=0(root)" >nul
  ```
  CMD interprets `<stdin>` as an input redirection operator reading from a file named `stdin`.
  Verbatim CMD error output:
  ```
  Le fichier specifie est introuvable.
  ```
  The pipeline crashes, printing a file-not-found system error.

---

### Observation 1.4: Disconnected Fastboot Indefinite Hang in `1_FLASHER_RECOVERY_ET_VBMETA.bat:19`
- **Location:** `dandelion_tool\1_FLASHER_RECOVERY_ET_VBMETA.bat`, lines 18–24.
- **Current Code:**
  ```cmd
  echo Verification de la detection du peripherique Fastboot...
  "%~dp0..\bin\fastboot.exe" devices
  if %errorlevel% neq 0 (
      echo [-] ERREUR : Impossible d'executer fastboot.exe.
      pause
      exit /b %errorlevel%
  )
  ```
- **Empirical Test:**
  When no handset is connected in Fastboot mode:
  ```cmd
  bin\fastboot.exe devices
  ```
  Returns 0 bytes on stdout and stderr, and exits with code 0 (`%errorlevel% == 0`).
  Because `%errorlevel%` is 0, the script passes the check and immediately executes line 32:
  ```cmd
  "%~dp0..\bin\fastboot.exe" --disable-verity --disable-verification flash vbmeta "%~dp0recovery\vbmeta.img"
  ```
  `fastboot.exe` prints `< waiting for any device >` and hangs indefinitely until the terminal process is forcibly killed.

---

### Observation 1.5: Missing `chcp 65001 >nul` in `MENU_DANDELION.bat`
- **Location:** `dandelion_tool\MENU_DANDELION.bat`, line 2.
- **Current Code:**
  ```cmd
  @echo off
  cd /d "%~dp0"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dandelion_tool.ps1"
  ```
- **Contract Reference:** `PROJECT.md` Command Exit Code Contract line 71:
  "Every batch script must enforce `chcp 65001 >nul` at line 2."
  All other scripts (`0_...bat`, `1_...bat`, `2_...bat`) include `chcp 65001 >nul` at line 2.

---

## 2. Logic Chain

1. **Item 1 (UsbDk Quoting & Exit Code):**
   - *Premise:* When calling an elevated MSI installation via PowerShell from CMD, the argument string passed to `msiexec.exe` must preserve path whitespace without injecting rogue escape characters, and the child exit code must be propagated.
   - *Empirical Finding:* In PowerShell, single quotes `'...'` inside `-Command "..."` are not evaluated; literal backslashes are preserved. Passing `'\"...'` injects `\"` into `Start-Process`, which `Start-Process` quotes as `" \"..."`.
   - *Tested Solution:* Using `('\"' + '%~dp0..\drivers\UsbDk_1.0.22_x64.msi' + '\"')` or `$env:USBDK_MSI` passes the exact string `"/i", "`"path`""` to `Start-Process`. Adding `-PassThru; exit $proc.ExitCode` forces PowerShell to exit with `msiexec`'s return code. Saving `set "EXIT_CODE=%errorlevel%"` after `mtk.py` and adding `if %EXIT_CODE% neq 0 exit /b %EXIT_CODE%` after `pause` ensures failure codes are preserved on script exit.

2. **Item 2 (CMD `for /f` Multi-Quote Stripping):**
   - *Premise:* In CMD `for /f ('command')`, having multiple pairs of quotes (`"path\adb.exe"` and `"id"`) causes `cmd /c` to strip the outermost quotes, breaking paths that contain spaces.
   - *Empirical Finding:* Prepending `call` prevents CMD's quote stripping rule because the command line begins with an identifier (`call`) rather than a quote character `"`. Furthermore, Android's `su` command accepts `su -c id` without inner quotes, eliminating secondary quoting entirely.
   - *Tested Solution:* `for /f "tokens=*" %%b in ('call "%~dp0..\bin\adb.exe" shell su -c id 2^>nul') do set ROOT_OUTPUT=%%b`. Tested in paths containing spaces (`mock adb\adb.exe`); executed with 100% reliability.

3. **Item 3 (`<stdin>` Redirection Crash):**
   - *Premise:* Any string containing `<` or `>` piped unquoted to another command in CMD is parsed as file redirection.
   - *Empirical Finding:* When `su` is absent, mksh outputs `/system/bin/sh: <stdin>[1]: su: not found`. Unquoted `echo %ROOT_OUTPUT% | ...` attempts to read from a file named `stdin`.
   - *Tested Solution:* Enclosing `%ROOT_OUTPUT%` in double quotes: `echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul`. The double quotes escape `<` and `>` from CMD stream interpretation while allowing `findstr` to match `uid=0(root)`.

4. **Item 4 (Fastboot Empty Device Detection & Guard):**
   - *Premise:* Fastboot exit code 0 does not imply a device is present. A flash script must verify device presence before executing flash commands.
   - *Empirical Finding:* When disconnected, `fastboot devices` outputs 0 bytes. Using a `for /f` loop to read the output into an environment variable `FB_DEV` reliably tests presence via `if not defined FB_DEV`.
   - *Tested Solution:* Capture `FB_DEV` via `for /f`. If `FB_DEV` is not defined, abort with an actionable error message and exit code 1. If defined, optionally verify `fastboot getvar product` against `dandelion`/`blossom` to prevent cross-device flashing.

5. **Item 5 (`MENU_DANDELION.bat` Codepage):**
   - *Premise:* Consistency and standards compliance require UTF-8 codepage enforcement at line 2.
   - *Tested Solution:* Insert `chcp 65001 >nul` at line 2 of `MENU_DANDELION.bat`.

---

## 3. Caveats

- **No live physical handset connected:** Empirical verification was performed using real Windows binaries (`adb.exe`, `fastboot.exe`, `msiexec.exe`, `python.exe`), mock responses, and synthetic edge-case strings (`(x86)`, spaces, `&`, `<stdin>`).
- **Scope limitation:** As an explorer agent adhering to read-only investigation rules, no files inside `dandelion_tool/` were modified directly. All changes are provided as exact remediation proposals for the implementer agent.

---

## 4. Conclusion & Exact Remediation Strategy

### 4.1 Remediation for `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`

#### Change A: UsbDk Elevation Quoting (Lines 33–36)
**Before:**
```cmd
    if /i "%INSTALL_USBDK%"=="O" (
        echo [*] Elevation des privileges Administrateur pour UsbDk...
        powershell -NoProfile -Command "Start-Process msiexec.exe -ArgumentList '/i', '\"%~dp0..\drivers\UsbDk_1.0.22_x64.msi\"' -Verb RunAs -Wait"
    ) else (
```
**After:**
```cmd
    if /i "%INSTALL_USBDK%"=="O" (
        echo [*] Elevation des privileges Administrateur pour UsbDk...
        set "USBDK_MSI=%~dp0..\drivers\UsbDk_1.0.22_x64.msi"
        powershell -NoProfile -Command "$proc = Start-Process msiexec.exe -ArgumentList '/i', ('\"' + $env:USBDK_MSI + '\"') -Verb RunAs -Wait -PassThru; exit $proc.ExitCode"
    ) else (
```

#### Change B: Preserving `%errorlevel%` on Exit (Lines 65–88)
**Before:**
```cmd
python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"

if %errorlevel% neq 0 (
    echo.
    echo =====================================================================
    echo [-] ERREUR CRITIQUE : L'operation mtkclient a echoue (code %errorlevel%).
    echo.
    echo Pistes de resolution :
    echo - Verifiez que le pilote UsbDk est installe (..\drivers\UsbDk_1.0.22_x64.msi).
    echo - Branchez le cable directement sur un port USB 2.0 a l'arriere du PC.
    echo - Reessayez la sequence : extinction complete, Vol+ et Vol- maintenus.
    echo =====================================================================
) else (
    echo.
    echo =====================================================================
    echo [+] SUCCES TOTAL : Bootloader deverrouille et protection FRP effacee !
    echo     Le telephone redemarre. L'ecran d'avertissement 'dm-verity'
    echo     au demarrage est normal et confirme le succes du deblocage.
    echo =====================================================================
)

echo.
pause
```
**After:**
```cmd
python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"
set EXIT_CODE=%errorlevel%

if %EXIT_CODE% neq 0 (
    echo.
    echo =====================================================================
    echo [-] ERREUR CRITIQUE : L'operation mtkclient a echoue (code %EXIT_CODE%).
    echo.
    echo Pistes de resolution :
    echo - Verifiez que le pilote UsbDk est installe (..\drivers\UsbDk_1.0.22_x64.msi).
    echo - Branchez le cable directement sur un port USB 2.0 a l'arriere du PC.
    echo - Reessayez la sequence : extinction complete, Vol+ et Vol- maintenus.
    echo =====================================================================
) else (
    echo.
    echo =====================================================================
    echo [+] SUCCES TOTAL : Bootloader deverrouille et protection FRP effacee !
    echo     Le telephone redemarre. L'ecran d'avertissement 'dm-verity'
    echo     au demarrage est normal et confirme le succes du deblocage.
    echo =====================================================================
)

echo.
pause
if %EXIT_CODE% neq 0 exit /b %EXIT_CODE%
```

---

### 4.2 Remediation for `2_INSTALLER_ROM_64BIT_ET_ROOT.bat`

#### Change A: Quotation Safe Echo for ROM Filename (Line 49)
**Before:**
```cmd
    echo [*] Copie de la ROM detectee : %%~nxf ...
```
**After:**
```cmd
    echo [*] Copie de la ROM detectee : "%%~nxf" ...
```

#### Change B: Multi-Quote Stripping & `<stdin>` Redirection Crash Fix (Lines 118–129)
**Before:**
```cmd
echo [2/2] Test des Privileges Superutilisateur Root (su -c "id")...
set ROOT_OUTPUT=non_defini
for /f "tokens=*" %%b in ('"%~dp0..\bin\adb.exe" shell su -c "id" 2^>nul') do set ROOT_OUTPUT=%%b

echo     Reponse de la commande : %ROOT_OUTPUT%
echo %ROOT_OUTPUT% | findstr /c:"uid=0(root)" >nul
if %errorlevel% equ 0 (
    echo [+] VALIDATION CONFORME : Privileges root obtenus avec succes (uid=0) !
) else (
    echo [-] ATTENTION : Privilege root non detecte ou demande refusee.
    echo     Verifiez que l'application Magisk est installee et que le superutilisateur est autorise.
)
```
**After:**
```cmd
echo [2/2] Test des Privileges Superutilisateur Root (su -c id)...
set ROOT_OUTPUT=non_defini
for /f "tokens=*" %%b in ('call "%~dp0..\bin\adb.exe" shell su -c id 2^>nul') do set ROOT_OUTPUT=%%b

echo     Reponse de la commande : %ROOT_OUTPUT%
echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul
if %errorlevel% equ 0 (
    echo [+] VALIDATION CONFORME : Privileges root obtenus avec succes (uid=0) !
) else (
    echo [-] ATTENTION : Privilege root non detecte ou demande refusee.
    echo     Verifiez que l'application Magisk est installee et que le superutilisateur est autorise.
)
```

---

### 4.3 Remediation for `1_FLASHER_RECOVERY_ET_VBMETA.bat`

#### Change A: Fastboot Device Presence Verification (Lines 18–26)
**Before:**
```cmd
echo Verification de la detection du peripherique Fastboot...
"%~dp0..\bin\fastboot.exe" devices
if %errorlevel% neq 0 (
    echo [-] ERREUR : Impossible d'executer fastboot.exe.
    pause
    exit /b %errorlevel%
)
echo.
```
**After:**
```cmd
echo Verification de la detection du peripherique Fastboot...
set "FB_DEV="
for /f "tokens=*" %%d in ('"%~dp0..\bin\fastboot.exe" devices 2^>nul') do (
    set "FB_DEV=%%d"
)

if not defined FB_DEV (
    echo.
    echo =====================================================================
    echo [-] ERREUR : Aucun peripherique Fastboot detecte !
    echo.
    echo Instructions de depannage :
    echo  1. Assurez-vous que le telephone est allume en mode FASTBOOT :
    echo     Eteindre completement, puis maintenir [VOLUME BAS] + [POWER].
    echo  2. Branchez le cable USB directement sur un port USB a l'arriere du PC.
    echo  3. Verifiez les pilotes 'Android Bootloader Interface' dans Windows.
    echo =====================================================================
    echo.
    pause
    exit /b 1
)

echo [+] Peripherique Fastboot detecte : %FB_DEV%
echo.

rem Verification de securite du modele (dandelion / blossom)
set "FB_PRODUCT="
for /f "tokens=2 delims=: " %%p in ('"%~dp0..\bin\fastboot.exe" getvar product 2^>^&1') do (
    if not defined FB_PRODUCT set "FB_PRODUCT=%%p"
)
if defined FB_PRODUCT (
    echo     Modele detecte : %FB_PRODUCT%
    if /i not "%FB_PRODUCT%"=="dandelion" if /i not "%FB_PRODUCT%"=="blossom" (
        echo [!] AVERTISSEMENT : Le peripherique detecte [%FB_PRODUCT%] ne correspond pas a dandelion/blossom !
        echo     Flash annule pour proteger l'appareil contre un mauvais micrologiciel.
        echo.
        pause
        exit /b 2
    )
)
echo.
```

---

### 4.4 Remediation for `MENU_DANDELION.bat`

#### Addition of `chcp 65001 >nul` (Line 2)
**Before:**
```cmd
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dandelion_tool.ps1"
```
**After:**
```cmd
@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dandelion_tool.ps1"
```

---

## 5. Verification Method

To independently verify these remediations:

1. **Verify UsbDk path handling in spaces and exit code:**
   ```cmd
   cmd /c "powershell -NoProfile -Command \"$proc = Start-Process python -ArgumentList 'print_argv.py', '/i', ('\\\"' + 'C:\Program Files (x86)\Test Path & Space\UsbDk.msi' + '\\\"') -NoNewWindow -Wait -PassThru; exit $proc.ExitCode\""
   ```
   *Expected result:* `ARG1=[/i]`, `ARG2=[C:\Program Files (x86)\Test Path & Space\UsbDk.msi]`, exit code `0`.

2. **Verify CMD `for /f` execution with `call` on paths with spaces:**
   ```cmd
   for /f "tokens=*" %b in ('call "%~dp0..\bin\adb.exe" shell su -c id 2^>nul') do @echo RESULT: %b
   ```
   *Expected result:* No `'C:\...' n'est pas reconnu` error; output is captured cleanly.

3. **Verify `<stdin>` quoting in CMD:**
   ```cmd
   set "ROOT_OUTPUT=/system/bin/sh: <stdin>[1]: su: not found"
   echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul
   echo %errorlevel%
   ```
   *Expected result:* Exits with code `1`, no `Le fichier specifie est introuvable` error.

4. **Verify Fastboot device absence detection:**
   Execute `1_FLASHER_RECOVERY_ET_VBMETA.bat` with no device connected.
   *Expected result:* Outputs `[-] ERREUR : Aucun peripherique Fastboot detecte !`, pauses, and exits with code `1` immediately without hanging on `< waiting for any device >`.

5. **Verify full E2E test suite compatibility:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "dandelion_tool\tests\run_tests.ps1" -Tier All
   ```
   *Expected result:* All assertions (Tier 1 through Tier 4) pass without regression.
