# Master Plan — dandelion_tool

## Goal
Build `dandelion_tool/` to automate the lifecycle of Xiaomi Redmi 10A (3GB RAM, SoC MT6762G, codename dandelion/blossom):
- BROM bootloader & FRP unlock
- Custom recovery & AVB disable
- 64-bit ROM (ARM64) + Root (Magisk/KernelSU)
- Interactive menu and documentation
- Strict isolation from Begonia files

## Strategy
Follow the Project Orchestration Pattern:
1. **Survey (Phase 0)**:
   - Explorer 1: Inspect existing Begonia tooling structure, relative binaries (`..\bin\adb.exe`, `fastboot.exe`, `..\src\mtkclient`), ergonomics, scripts style.
   - Explorer 2: Technical analysis of MT6762G (Helio G25) BROM exploit, mtkclient payload / arguments, DA / preloader requirements, FRP partition offsets/format, seccfg unlock method.
   - Spec Miner / Explorer 3: 64-bit custom ROM (LineageOS 20 arm64 / crDroid 9 arm64) & Recovery (TWRP / OrangeFox) availability for dandelion/blossom, partition scheme (A/B or A-only / dynamic partitions), vbmeta flags, Magisk/KernelSU root injection.
2. **Decomposition & Contracts (Phase 1)**:
   - Synthesize explorer findings into `PROJECT.md` (Architecture, Feature Inventory, Milestones, Interface Contracts, Code Layout).
   - Formulate E2E Test Infra (`TEST_INFRA.md`).
3. **Execution (Phase 2)**:
   - Implementation Track milestones via sub-orchestrators or iteration loops (Explorer -> Worker -> Reviewers -> Challengers -> Auditor -> Gate).
   - Parallel E2E Testing Track.
4. **Acceptance (Phase 3)**:
   - Full test suite execution and verification.
5. **Report to Sentinel (Phase 4)**:
   - Detailed completion report with verification evidence.
