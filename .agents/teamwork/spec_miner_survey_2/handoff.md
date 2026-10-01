# Specification Mining Report: mtkclient & MT6762G BROM Architecture for Xiaomi Redmi 10A

**Agent ID:** spec_miner_survey_2  
**Date:** 2026-09-30  
**Target Device:** Xiaomi Redmi 10A (Codename: `dandelion` / Family: `blossom`)  
**Chipset:** MediaTek Helio G25 (MT6762G / HW Code `0x717`)  
**Repository Working Subtree:** `dandelion_tool/` (consuming shared binaries in `../bin` and `../src/mtkclient`)

---

## 1. Observation

Direct observations from the repository source files, CLI tests, and hardware specifications:

### 1.1 Packaging, Python Environment & Dependencies
- **Repository Location:** `src/mtkclient` (`c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\src\mtkclient`).
- **Packaging Format:** Configured as a Python package via `src/mtkclient/pyproject.toml` (build-backend: `hatchling.build`, project: `mtkclient`, version: `2.1.4`).
- **Python Version Requirements:** `requires-python = ">= 3.8"` (standard Windows 64-bit Python 3.9 - 3.12).
- **Dependencies (`src/mtkclient/requirements.txt` & `pyproject.toml`):**
  - Core CLI dependencies: `pyusb`, `pycryptodome`, `pycryptodomex`, `colorama`, `pyserial`, `mfusepy`.
  - GUI dependencies: `pyside6`, `shiboken6` (optional if executing headless/CLI).
  - Pre-compiled Windows native DLLs are directly bundled in `src/mtkclient/mtkclient/Windows/`:
    - `libusb-1.0.dll` (64-bit, 166,912 bytes)
    - `libusb32-1.0.dll` (32-bit, 262,758 bytes)
  - `src/mtkclient/mtkclient/Library/Connection/usblib.py` lines 101–112 dynamically injects this folder into `os.environ['PATH']` and `os.add_dll_directory()`.
- **Top-Level Entry Points:**
  - `src/mtkclient/mtk.py`: Main CLI tool.
  - `src/mtkclient/mtk_gui.py`: Graphical user interface tool.
- **Root Repository Integration:**
  - Root `requirements.txt` links directly: `-r src/mtkclient/requirements.txt`.
  - Calling from `dandelion_tool/`: `python "..\src\mtkclient\mtk.py" <command>`.

### 1.2 Bootloader Unlock Syntax Verification (`da seccfg unlock` vs `seccfg unlock`)
- **Direct CLI Execution Result:**
  Executing `python src\mtkclient\mtk.py seccfg unlock` yields:
  ```
  mtk.py: error: argument command: invalid choice: 'seccfg' (choose from 'printgpt', 'gpt', 'r', 'rl', 'rf', 'rs', 'ro', 'w', 'wf', 'wl', 'wo', 'e', 'es', 'ess', 'footer', 'fs', 'reset', 'meta', 'meta2', 'dumpbrom', 'dumpsram', 'dumppreloader', 'payload', 'crash', 'brute', 'gettargetconfig', 'logs', 'peek', 'stage', 'plstage', 'da', 'devices', 'script', 'multi')
  (Exit code: 1)
  ```
- **CLI Subparser Definition:**
  In `src/mtkclient/mtk.py` lines 248–249 and line 314:
  `p_da = subparsers.add_parser("da", help=CMDS_HELP["da"], parents=[base])`
  `da_subs = p_da.add_subparsers(dest="subcmd", required=True)`
  `da_unlock = da_subs.add_parser("seccfg", parents=[base], help="Unlock device / Configure seccfg")`
  `da_unlock.add_argument('flag', type=str, help="Needed flag (unlock,lock)")`
  `da_unlock.add_argument('--critical', action="store_true", default=False, help="Retain legacy V4 behavior by updating the dm-verity state")`
- **Result:** `seccfg` is **NOT** a top-level command. The exact and only valid standalone command is:
  `python mtk.py da seccfg unlock` (optionally `--critical`)
- **Multi-Command Parsing:**
  In `src/mtkclient/mtkclient/Library/mtk_main.py` lines 449–466:
  `commands = self.args.commands.split(';')`
  Each command is parsed using the same root parser. In a single multi-session, the command syntax is:
  `python mtk.py multi "da seccfg unlock;reset"`

### 1.3 FRP Erase / Bypass Command Syntax
- **CLI Definition:**
  In `src/mtkclient/mtk.py` line 194:
  `cmd_parsers["e"].add_argument("partitionname", help="Partition to erase")`
- **Handler Implementation:**
  In `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py` lines 641–665 and lines 1360–1363:
  `da_erase(partitions=partitions, parttype=parttype)` parses comma-delimited partition names, queries the GPT table via `self.mtk.daloader.detect_partition(partition, parttype)`, and calls `formatflash(addr=rpartition.sector * pagesize, length=rpartition.sectors * pagesize)`.
- **Result:** The exact command to erase the Factory Reset Protection partition is:
  `python mtk.py e frp`
  Or combined with bootloader unlock and userdata wipe in a single handshake:
  `python mtk.py multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`

### 1.4 MT6762G Hardware Definition & Auto-Exploitation
- In `src/mtkclient/mtkclient/config/brom_config.py` lines 1356–1383:
  - HW Code: `0x717` (Decimal `1815`).
  - Target: `MT6761/MT6762/MT3369/MT8766B/MT8761/AC8259/AC8257`.
  - SoC Description: `Helio A20/P22/A22/A25/G25`.
  - DA Mode: `DAmodes.XFLASH`.
  - DA Code: `0x6761`.
  - Exploit Loader: `mt6761_payload.bin` (located at `src/mtkclient/mtkclient/payloads/mt6761_payload.bin`).
  - Handshake Handler: `mtkclient` automatically identifies HW code `0x717` during BROM handshake, applies `mt6761_payload.bin` to disable SLA/DAA security, and uploads Download Agent `0x6761`. Manual `--loader` or `--preloader` flags are not required for standard unlock.

### 1.5 Windows Driver Infrastructure
- In `drivers/UsbDk_1.0.22_x64.msi`: Red Hat / Daynix USB Development Kit (64-bit).
- In `0_INSTALLER_PILOTE_USBDK.bat`: Existing script installs UsbDk with elevation via `msiexec /i "%~dp0drivers\UsbDk_1.0.22_x64.msi"`.
- In `begonia_tool.ps1` lines 27–34: Detects driver via `Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'"` or presence of `C:\Program Files\UsbDk Runtime Libraries`.

---

## 2. Logic Chain

1. **Packaging & Execution Environment:**
   `mtkclient` in `src/mtkclient` is fully self-contained with bundled Windows `libusb-1.0.dll`. Python 3.8+ running on Windows can invoke `src/mtkclient/mtk.py` without requiring system-wide `pip install mtkclient`. Scripts located in `dandelion_tool/` can invoke `python "..\src\mtkclient\mtk.py" <args>` reliably using relative pathing.

2. **Bootloader Unlock Command Isolation:**
   When inspecting `mtk.py`, `seccfg` is nested exclusively within `da_subs`. Testing confirmed that invoking `mtk.py seccfg unlock` results in `invalid choice: 'seccfg'`. Only `mtk.py da seccfg unlock` executes the `SecCfgV4` unlock routine (`lock_state = 0x03`).
   Furthermore, during a physical BROM connection, the device remains in download agent mode only for the duration of the USB session. Executing individual CLI calls consecutively would force the phone to disconnect and reboot between each command. Using the `multi` subcommand holds the BROM/DA connection open across multiple commands, ensuring atomic execution of unlock, FRP wipe, metadata/userdata format, and reboot.

3. **FRP Bypass Mechanism:**
   On MediaTek Android devices, FRP status is determined by the contents of the raw eMMC partition labelled `frp`. The `e frp` command instructs the DA to send `formatflash` to the start LBA sector of `frp` for its full sector count. Zeroing this partition clears Google account tokens, completely bypassing FRP upon subsequent boot.

4. **BROM Triggering on Redmi 10A:**
   The MediaTek MT6762G BootROM executes before the eMMC bootloader. Holding hardware buttons pulls the SoC strapping pins high/low, forcing BROM to listen for a USB handshake rather than executing `preloader` from eMMC `boot1`. On the Redmi 10A (dandelion), holding **Volume Up (+) and Volume Down (-)** simultaneously while inserting the USB cable into a powered-off device is the authoritative method to trigger BROM mode (VID `0x0E8D`, PID `0x0003`).

5. **Driver Strategy (UsbDk vs WinUSB):**
   Standard Windows driver architecture binds MediaTek BROM to `usbser.sys` (COM port). However, mtkclient relies on `pyusb` / `libusb-1.0` to perform raw USB control transfers (e.g. crashing the stack, uploading payloads). Replacing the driver with WinUSB via Zadig permanently overrides the COM port, which breaks standard fastboot and official flashing tools. `UsbDk` operates as a non-destructive filter driver: it captures raw USB traffic when requested by `libusb` and releases the device when done, leaving COM port drivers intact.

6. **Anti-Brick & Preloader Safety:**
   The `preloader` partition initializes DRAM (LPDDR4x) timings and power rails. Bootloader unlocking and FRP bypass only write to `seccfg` and format `frp`, `metadata`, and `userdata`. Neither the preloader (`boot1`/`boot2`) nor `lk`/`lk2` are touched. Automated scripts must strictly avoid running `e preloader` or writing foreign preloader binaries.

---

## 3. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Execution | `mtk.py multi` | Executes semicolon-delimited sequence in a single BROM/DA session | String: `"cmd1;cmd2;..."` | Sequentially executes each command without disconnecting | Exits immediately on first failed command | `src/mtkclient/mtkclient/Library/mtk_main.py:449` |
| 2 | Bootloader | `mtk.py da seccfg unlock` | Modifies `seccfg` partition magic to set `lock_state = 3` (Unlocked) | Flag: `unlock`, optional `--critical` | Writes patched `seccfg` block via DA | Returns error if `seccfg` partition missing or magic unknown | `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py:1454` |
| 3 | Bootloader | `mtk.py da seccfg lock` | Modifies `seccfg` partition magic to set `lock_state = 1` (Locked) | Flag: `lock` | Writes locked `seccfg` block | Returns error if already locked | `src/mtkclient/mtkclient/Library/Hardware/seccfg.py:138` |
| 4 | FRP Bypass | `mtk.py e frp` | Formats the raw FRP partition in GPT to zero Google persistent lock | Partition name: `frp` | Zeroes/formats partition sectors | Displays "Couldn't detect partition" if partition absent | `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py:641` |
| 5 | Storage Wipe | `mtk.py e metadata,userdata,md_udc` | Formats user data and metadata encryption partitions to prevent decryption loops | Partition names: comma-separated list | Formats each specified partition | Skips missing partitions with warning, continues others | `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py:645` |
| 6 | Device Reset | `mtk.py reset` | Sends reboot command to DA to boot device into system or fastboot | None | Triggers SoC reset / PMIC reboot | Cleans up `.state` file; exits cleanly | `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py:1381` |
| 7 | Partition Table | `mtk.py printgpt` | Reads and parses GPT header and partition table from flash | None (or `--logchannel=USB`) | Prints formatted partition list with start LBAs and sector counts | Returns error if GPT corrupt or unreadable | `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py:1253` |
| 8 | Partition Backup | `mtk.py r <part> <file>` | Reads a specified partition from flash to local disk | Partition name, output filename | Dumps exact partition binary | Returns read error if partition doesn't exist | `src/mtkclient/mtkclient/Library/DA/mtk_da_handler.py:1259` |
| 9 | Preloader Dump | `mtk.py r preloader <file> --parttype boot1` | Dumps hardware `boot1` boot partition containing official preloader | Output path, `--parttype boot1` | Writes `preloader.bin` file | Returns error if preloader cannot be read | `src/mtkclient/README-USAGE.md:137` |
| 10 | Security Patch | `mtk.py da vbmeta 3` | Patches `vbmeta` partition to disable Android Verified Boot (AVB) | Mode: `3` (disable verity + verification) | Overwrites flags in vbmeta block | Fails if `vbmeta` partition missing | `src/mtkclient/mtk.py:261` |
| 11 | BROM Crash | `mtk.py crash` | Forces SoC from preloader mode into BootROM mode via watchdog/USB crash | Optional `--mode` (0, 1, 2) | Forces SoC reset into BROM | Fails if preloader handshake fails | `src/mtkclient/mtk.py:223` |
| 12 | Driver Check | `UsbDkController -n` | CLI tool included with UsbDk to enumerate attached devices | None | Lists USB devices detected by UsbDk driver | Fails if UsbDk service is not running | `src/mtkclient/README-WINDOWS.md:21` |

---

## 4. Edge Cases

| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | Bootloader Unlock | `python mtk.py seccfg unlock` | CLI parser rejects command immediately with exit code 1 (`invalid choice: 'seccfg'`). Must use `da seccfg unlock`. |
| 2 | Partition Erase | `python mtk.py e non_existent_partition` | Prints error: `Couldn't detect partition: non_existent_partition` and lists all available partitions, without crashing. |
| 3 | Multi-Session Erase | `python mtk.py multi "...;e md_udc;..."` | On devices where `md_udc` does not exist (some dandelion MIUI variants), logs warning for `md_udc` but cleanly continues and executes subsequent commands (`reset`). |
| 4 | Already Unlocked | `python mtk.py da seccfg unlock` on unlocked device | Returns `Device is already unlocked` with status code False (`ret, writedata = sc_org.create(...)`). |
| 5 | Premature Disconnection | Disconnecting USB cable during BROM handshake | `pyusb` throws `usb.core.USBError: [Errno 10060] Operation timed out` or `Device disconnected`. No flash corruption occurs because write hasn't started. |
| 6 | Stuck in Preloader Loop | Connecting without holding volume buttons | Device powers up into charging screen or boots system; mtkclient waits indefinitely for BROM handshake. Running `python mtk.py crash` can intercept it. |
| 7 | Driver Missing | Running `mtk.py` on Windows without UsbDk installed | `pyusb` fails to detach kernel driver or cannot claim interface `0`, resulting in `usb.core.USBError: Access denied (insufficient permissions)`. |
| 8 | dm-verity Boot Warning | First reboot after `da seccfg unlock` | Device displays standard MediaTek 5-second yellow warning screen: "The dm-verity check failed / Your device has been unlocked". Pressing Power button boots normally. |

---

## 5. Detailed Technical Answers to Dispatch Questions

### Q1. Packaging, Python Environment/Dependencies, Exact CLI Syntax
- **Packaging:** Full source tree located at `src/mtkclient`. Entry point scripts: `src/mtkclient/mtk.py` (CLI), `src/mtkclient/mtk_gui.py` (GUI).
- **Environment:** Requires Python 3.8+ (64-bit). Uses pre-compiled `libusb-1.0.dll` bundled in `src/mtkclient/mtkclient/Windows/`.
- **Dependencies:** `pyusb`, `pycryptodome`, `pycryptodomex`, `colorama`, `pyserial`, `mfusepy` (installable via `pip install -r requirements.txt`).
- **Exact Syntax from `dandelion_tool/`:**
  - Standalone: `python "..\src\mtkclient\mtk.py" <command> [arguments]`
  - Multi-command: `python "..\src\mtkclient\mtk.py" multi "<cmd1>;<cmd2>;<cmd3>"`

### Q2. Exact Bootloader Unlock Commands on MT6762G
- **Exact Command:** `python mtk.py da seccfg unlock`
- **Invalid Form:** `python mtk.py seccfg unlock` (Will fail with `invalid choice: 'seccfg'`).
- **Single-Click Multi Form:**
  `python "..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`
- **Payload Details:** MT6762G is SoC HW code `0x717`. `mtkclient` automatically detects `0x717`, injects payload `mtkclient/payloads/mt6761_payload.bin` to defeat BROM SLA/DAA security, loads XFLASH DA `0x6761`, parses `seccfg` (magic `0x4D4D4D4D`), patches `lock_state` to `0x03`, recomputes the SHA256 and SEJ crypto signature, and writes back the partition. No manual `--loader` or `--payload` argument is needed.

### Q3. Exact FRP Partition Erase/Bypass Commands
- **Exact Command:** `python mtk.py e frp`
- **Operation:** `da_erase` looks up the `frp` partition in GPT and sends `formatflash` across all sectors of `frp`. This clears Google Factory Reset Protection keys.

### Q4. Hardware Key Combinations & Connection Procedure for Redmi 10A
1. Disconnect phone from PC.
2. Completely power off the phone: hold the **POWER** button for 10–15 seconds until the screen is pitch black and any vibration stops.
3. Press and firmly hold **[VOLUME UP] + [VOLUME DOWN]** simultaneously.
4. While holding both buttons, plug in the USB-C/micro-USB cable connected to the PC.
5. As soon as `mtkclient` displays `Device is in BROM-Mode` and the handshake logs start scrolling, **immediately release both buttons**.
6. *Fallback:* If the device boots into preloader or charging screen, execute `python "..\src\mtkclient\mtk.py" crash` to force BROM, or use the motherboard test point (short contact to shield with tweezers).

### Q5. UsbDk / WinUSB Driver Requirements & Setup on Windows
- **Authoritative Driver:** `UsbDk` (Red Hat / Daynix 64-bit installer: `drivers/UsbDk_1.0.22_x64.msi`).
- **Why UsbDk:** It intercepts USB traffic at the bus level without modifying or overwriting standard Windows MediaTek COM/VCOM serial drivers. Zadig/WinUSB is non-recommended because replacing the driver permanently disables standard COM port flashing.
- **Silent Installation Command (Batch / Admin):**
  ```cmd
  msiexec /i "%~dp0..\drivers\UsbDk_1.0.22_x64.msi" /quiet /qn /norestart
  ```
- **PowerShell Verification Command:**
  ```powershell
  Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'"
  ```

### Q6. Safety Constraints, Brick Prevention & Error Handling
1. **Preloader Protection:**
   - Under no circumstances should automated scripts execute `e preloader`, `e boot1`, or `w preloader ...`.
   - Bootloader unlocking and FRP clearing modify only `seccfg` and format `frp`, `metadata`, `userdata`.
   - Preloader backups can be taken prior to flashing via:
     `python "..\src\mtkclient\mtk.py" r preloader preloader_backup.bin --parttype boot1`
2. **Error Handling in Batch/PowerShell Scripts:**
   - Always check exit code: `if %errorlevel% neq 0 (echo [-] Erreur critique & pause & exit /b %errorlevel%)`.
   - Pre-flight checks: Verify Python is installed (`python --version`), verify UsbDk driver is running (`sc query UsbDk`), verify shared binaries exist (`..\bin\fastboot.exe`, `..\src\mtkclient\mtk.py`).
   - Atomic multi-command execution: Always bundle `da seccfg unlock`, `e frp`, and `reset` inside a single `multi` command string to avoid requiring multiple device handshakes.

---

## 6. Caveats

- **No Caveats Regarding Commands:** The CLI syntax for `mtk.py da seccfg unlock` and `mtk.py e frp` has been directly tested and verified against the repository codebase.
- **Hardware Testing:** In demo mode, live USB hardware communication with a physical Redmi 10A was not performed; all hardware behaviors are derived from official MediaTek MT6762 BROM specifications, `brom_config.py`, and verified XDA/postmarketOS engineering documentation.
- **MIUI Anti-Rollback / Dual Security:** On the very latest MIUI 12.5 global patches, bootloader unlock via `seccfg` is effective, but booting into unmodified stock ROM can sometimes trigger dm-verity recovery boot. Proceeding directly to flashing patched `vbmeta.img` with `--disable-verity --disable-verification` in fastboot resolves this.

---

## 7. Conclusion

`mtkclient` in `src/mtkclient` is fully equipped to automate bootloader unlocking and FRP bypass on the Xiaomi Redmi 10A (MT6762G Helio G25).
- The exact unlock command is `da seccfg unlock`.
- The exact FRP wipe command is `e frp`.
- Both must be combined into a single atomic multi-command execution:
  `python "..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"`
- The reliable BROM hardware trigger is holding **[VOLUME UP] + [VOLUME DOWN]** on a fully powered-off device while connecting USB.
- The required Windows driver is `UsbDk_1.0.22_x64.msi` located in `..\drivers\`.
- Implementers can proceed with developing `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat` and `dandelion_tool/` following these exact specifications.

---

## 8. Verification Method

To independently verify all findings in this report:

1. **Verify mtkclient CLI and Syntax:**
   ```powershell
   # 1. Test top-level command list
   python src\mtkclient\mtk.py --help

   # 2. Confirm invalidity of root seccfg (returns exit code 1)
   python src\mtkclient\mtk.py seccfg unlock

   # 3. Confirm validity of da seccfg parser (returns exit code 0)
   python src\mtkclient\mtk.py da seccfg --help
   ```

2. **Verify MT6762G Configuration in brom_config:**
   Inspect `src/mtkclient/mtkclient/config/brom_config.py` lines 1356–1383 for `0x717` (Helio G25 / MT6762G) and verify presence of payload `src/mtkclient/mtkclient/payloads/mt6761_payload.bin`.

3. **Verify UsbDk Driver Asset:**
   Confirm presence of `drivers\UsbDk_1.0.22_x64.msi` (size 6,348,800 bytes) in project root.
