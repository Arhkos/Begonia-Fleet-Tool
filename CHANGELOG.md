# Changelog

Tous les changements notables sont documentes ici.
Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)

## [Unreleased]

### A venir
- Verification SHA256 des images de partitions avant le flash
- Templates d'Issues GitHub

## [1.0.0] - 2026-08-23

### Ajoute
- Pipeline complet en 4 etapes pour Xiaomi Redmi Note 8 Pro (Begonia / MT6785)
- 0_INSTALLER_PILOTE_USBDK.bat : Installation 1-clic du pilote UsbDk (Red Hat/Daynix)
- 1_DEVERROUILLER_BOOTLOADER_ET_FRP.bat : Deverrouillage Bootloader + Bypass FRP en BROM
- 2_RESTAURER_STOCK_EEA_UNBRICK.bat : Flash integral 29 partitions MIUI 12.5.15.0 EEA
- 3_FLASHER_RECOVERY_ET_VBMETA.bat : Flash recovery BRP 3.6 + desactivation AVB 2.0
- 4_ENVOYER_ROM_SUR_TELEPHONE.bat : Copie automatique du firmware et ROM via ADB
- begonia_tool.ps1 : Menu interactif PowerShell avec diagnostic d'environnement
- src/flash_stock_complete.py : Orchestrateur Python avec protection anti-brick
- SECURITY.md, CONTRIBUTING.md, CHANGELOG.md
- README bilingue FR/EN (README.md + README.en.md)
- Workflow CI/CD GitHub Actions (.github/workflows/linting.yml)
