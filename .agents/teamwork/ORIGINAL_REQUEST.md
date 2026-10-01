# Original User Request

## Initial Request — 2026-09-30T21:10:32Z

Créer un module d'outillage dédié `dandelion_tool` au sein du dépôt pour automatiser le cycle de vie du Xiaomi Redmi 10A (3 Go RAM, SoC MT6762G, nom de code *dandelion* / famille *blossom*) : déverrouillage Bootloader en mode BROM, flash d'un recovery custom/vbmeta, installation d'une ROM 64-bit (ARM64) avec accès Root, sans aucune modification des fichiers existants du Redmi Note 8 Pro.

Working directory: c:\Users\Arhkos\Documents\antigravity\peaceful-babbage\dandelion_tool
Integrity mode: demo

## Requirements

### R1. Isolation Stricte & Réutilisation des Binaires
Créer l'arborescence dans un sous-dossier dédié `dandelion_tool/`. Les scripts existants à la racine et les dossiers `recovery/`, `roms/`, `stock_firmware/` de Begonia doivent rester 100% intacts. Les scripts de `dandelion_tool` doivent réutiliser de manière relative les exécutables communs (`..\bin\adb.exe`, `..\bin\fastboot.exe`, `..\src\mtkclient`).

### R2. Automatisation Déverrouillage Bootloader & FRP BROM (MT6762G)
Fournir les scripts batch/powershell exécutables en 1-clic pour le Redmi 10A afin d'intercepter le mode BootROM matériel (MT6762G) via `mtkclient` + `UsbDk`, réécrire la partition `seccfg` en mode déverrouillé, et effacer la partition FRP.

### R3. Pipeline Recovery Custom & Désactivation AVB
Fournir la procédure et les scripts Fastboot pour désactiver Android Verified Boot (`vbmeta.img` avec `--disable-verity --disable-verification`) et flasher un Recovery Custom (TWRP / OrangeFox) compilé pour `dandelion` / `blossom`.

### R4. Déploiement Custom ROM 64-bit & Intégration Root
Sélectionner et intégrer une solution de ROM 64-bit unifiée (LineageOS 20 arm64 ou crDroid 9 arm64 pour blossom) accompagnée d'une méthode d'injection du Root (Magisk v26+ ou KernelSU) opérationnelle pour un environnement 64-bit (`aarch64` / `arm64-v8a`), avec la documentation des sources et sommes de contrôle (checksums).

### R5. Interface et Documentation Technique
Fournir un script d'accueil ou menu clair (`MENU_DANDELION.bat` ou équivalent) calqué sur l'ergonomie du projet Begonia, ainsi qu'un guide Markdown (`README.md` dans `dandelion_tool/`) détaillant le déroulement chronologique, les combinaisons de touches matérielles du Redmi 10A, les pièges à éviter (ne pas écraser le preloader) et les commandes ADB de vérification du passage en 64-bit et du root.

## Acceptance Criteria

### Non-Régression & Structure
- [ ] Aucun fichier existant à la racine ou dans les modules Begonia n'est modifié (`git status` ne montre que des ajouts dans `dandelion_tool/`).
- [ ] Le répertoire `dandelion_tool/` contient sa propre structure (`recovery/`, `roms/`, scripts batch/powershell).

### Scripts d'Exécution
- [ ] Les scripts `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat`, `1_FLASHER_RECOVERY_ET_VBMETA.bat`, `2_INSTALLER_ROM_64BIT_ET_ROOT.bat` (ou équivalents structurés) sont présents et fonctionnels sous Windows PowerShell / CMD.
- [ ] Les chemins relatifs vers `..\bin` et `..\src\mtkclient` sont correctement configurés et testés.

### Vérification Technique Système
- [ ] Documentation claire et scriptée de la commande de validation de l'architecture : `adb shell getprop ro.product.cpu.abi` retournant impérativement `arm64-v8a`.
- [ ] Documentation claire et scriptée de la validation du binaire root : `adb shell su -c "id"` confirmant les privilèges `uid=0(root)`.
