## 2026-09-30T21:18:31Z
You are worker_1, an implementation worker subagent.
Your working directory is: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\worker_1\
The verbatim original user request is located at: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\ORIGINAL_REQUEST.md
You MUST read c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\ORIGINAL_REQUEST.md before starting work.

Also read:
- Project Specification: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\orchestrator_1\PROJECT.md
- Survey 1 (Architecture & Conventions): c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\explorer_survey_1\handoff.md
- Survey 2 (MT6762G BROM & mtkclient): c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\spec_miner_survey_2\handoff.md
- Survey 3 (Recovery, AVB, ROM 64-bit & Root): c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\.agents\teamwork\spec_miner_survey_3\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

CRITICAL NON-REGRESSION CONSTRAINT:
You have EXCLUSIVE write ownership of `c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool\` (EXCEPT `dandelion_tool\tests\` which is owned by test_writer).
You MUST NOT modify or touch ANY file outside `dandelion_tool/`. All existing files at repository root and in `recovery/`, `roms/`, `stock_firmware/`, `src/`, `bin/`, `drivers/` MUST remain 100% untouched.

Objective & Deliverables:
Create the complete, operational, production-ready `dandelion_tool/` module for the Xiaomi Redmi 10A (3GB RAM, MT6762G, codename dandelion/blossom):

1. `dandelion_tool\0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`
2. `dandelion_tool\1_FLASHER_RECOVERY_ET_VBMETA.bat`
3. `dandelion_tool\2_INSTALLER_ROM_64BIT_ET_ROOT.bat`
4. `dandelion_tool\MENU_DANDELION.bat`
5. `dandelion_tool\dandelion_tool.ps1`
6. `dandelion_tool\README.md`
7. `dandelion_tool\recovery\` (`vbmeta.img`, `recovery.img`)
8. `dandelion_tool\roms\` (`README_ROMS.md`, `Magisk-v26.4.apk`)
