# Dandelion Tool — Manuel d'Automatisation & Déploiement Xiaomi Redmi 10A

**Module d'outillage dédié et autonome pour le cycle de vie complet du Xiaomi Redmi 10A**  
*SoC MediaTek Helio G25 (MT6762G / HW 0x717) | 3 Go RAM | Nom de code : dandelion (Famille blossom)*

---

## 1. Vue d'Ensemble du Matériel & Architecture Système

Le **Xiaomi Redmi 10A** (modèles internes `220233L2G`, `220233L2I`, `220233L2C`, `220233L2A`) repose sur la plateforme **MediaTek Helio G25 (MT6762G)** :
- **CPU :** 8 cœurs ARM Cortex-A53 (Architecture ARMv8-A, 64-bit natif `aarch64`).
- **GPU :** PowerVR GE8320.
- **RAM :** 3 Go LPDDR4X.
- **Stockage :** 64 Go eMMC 5.1.
- **Nom de code spécifique :** `dandelion` (variante `dandelion_c3l2`).
- **Arborescence unifiée :** Famille `blossom` (partagée avec les Redmi 9A, 9C, 9C NFC, 9i).

### La problématique du bridage 32-bit sur firmware stock
Sur le système d'origine MIUI 12.5 (Android 10/11), Xiaomi a compilé l'espace utilisateur en **32-bit** (`ro.product.cpu.abi=armeabi-v7a`) avec un noyau bridé en `CONFIG_ANDROID_BINDER_IPC_32BIT=y`. Ce choix historique d'économie de mémoire pour les variantes d'entrée de gamme 2 Go handicape lourdement la version 3 Go :
- Blocage des applications 64-bit récentes et des moteurs Web modernes.
- Gestion mémoire sous-optimale limitant le multitâche.

**Dandelion Tool** permet de déverrouiller le bootloader en mode matériel (BootROM), de désactiver la protection Android Verified Boot (AVB), d'injecter un Custom Recovery, et de migrer l'appareil vers une **Custom ROM 64-bit native** (`arm64-v8a`) avec accès **Root Magisk v26+**.

---

## 2. Règle de Sécurité Critique Anti-Brick (Protection Preloader)

> ### ⚠️ AVERTISSEMENT MAJEUR — PROTECTION DE LA PARTITION PRELOADER
> Sur les plateformes MediaTek MT6762G, le code d'initialisation matérielle de bas niveau et les timings DRAM LPDDR4X résident dans les blocs de démarrage matériel de l'eMMC nommés `boot1` et `boot2`, exposés logiquement sous le nom de partition **`preloader`**.
>
> - **Ce qu'il ne faut JAMAIS faire :**
>   - Ne lancez **JAMAIS** de commande d'effacement du preloader (`mtk.py e preloader` ou `e boot1`).
>   - Ne tentez **JAMAIS** de flasher un binaire de preloader non authentique ou corrompu.
> - **Comportement garanti des scripts Dandelion Tool :**
>   - Toutes les opérations de déverrouillage et de réinitialisation ciblent strictement `seccfg` (configuration de sécurité), `frp` (effacement du verrou Google), `metadata`, et `userdata`.
>   - **Le preloader d'origine demeure 100% intouché et préservé**, garantissant l'impossibilité de briquer définitivement le processeur.

---

## 3. Combinaisons de Touches Matérielles (Hardware Key Map)

| Mode Cible | Téléphone Éteint / Allumé | Touches à Maintenir | Comportement Écran / Indicateur | Rôle & Protocole |
| :--- | :--- | :--- | :--- | :--- |
| **BootROM (BROM)** | Éteint (10-15s Power) | `[VOLUME HAUT]` + `[VOLUME BAS]` | Écran noir complet, détection USB `0x0E8D:0x0003` | Interception mtkclient de bas niveau, déverrouillage seccfg et effacement FRP |
| **FASTBOOT** | Éteint | `[VOLUME BAS]` + `[POWER]` | Logo FASTBOOT (lapin / texte orange) | Flash VBMeta, Recovery et communication fastboot.exe |
| **RECOVERY** | Éteint | `[VOLUME HAUT]` + `[POWER]` | Logo OrangeFox / TWRP | Format Data, flash Custom ROM 64-bit et injection Magisk |
| **Forçage Extinction**| N'importe quel état | `[POWER]` maintenu 15s | Écran s'éteint, extinction matérielle | Réinitialisation en cas de freeze |

---

## 4. Architecture des Fichiers & Réutilisation Relative

`dandelion_tool/` est un sous-module 100% isolé au sein du projet. Il n'altère aucun fichier du projet Begonia et consomme les outils partagés via des chemins relatifs :

```
peaceful-babbage/
├── bin/                             # [PARTAGÉ - LECTURE SEULE] adb.exe, fastboot.exe
├── drivers/                         # [PARTAGÉ - LECTURE SEULE] UsbDk_1.0.22_x64.msi
├── src/mtkclient/                   # [PARTAGÉ - LECTURE SEULE] Outil Python mtkclient v2.1.4
└── dandelion_tool/                  # [MODULE DÉDIÉ DANDELION / BLOSSOM]
    ├── MENU_DANDELION.bat           # Lanceur 1-clic du menu interactif PowerShell
    ├── dandelion_tool.ps1           # Console de gestion interactive complète
    ├── 0_DEVERROUILLER_BOOTLOADER_DANDELION.bat  # Étape 0 : Déverrouillage BROM & FRP
    ├── 1_FLASHER_RECOVERY_ET_VBMETA.bat         # Étape 1 : Fastboot AVB Bypass & Recovery
    ├── 2_INSTALLER_ROM_64BIT_ET_ROOT.bat        # Étape 2 : Déploiement ROM & Root + Checks
    ├── README.md                    # Ce manuel technique
    ├── recovery/
    │   ├── recovery.img             # Custom Recovery compilé pour blossom/dandelion
    │   └── vbmeta.img               # Image VBMeta AVB0 4096 octets (flags désactivés)
    └── roms/
        ├── README_ROMS.md           # Fiches techniques, miroirs officiels et SHA256
        └── Magisk-v26.4.apk         # Binaire officiel Magisk root v26.4
```

---

## 5. Déroulement Chronologique du Pipeline (Étapes 0 à 4)

### Étape 0 : Installation du Pilote UsbDk
- **Script :** Option `[1]` de `MENU_DANDELION.bat` ou double-clic sur `..\drivers\UsbDk_1.0.22_x64.msi`.
- **Utilité :** Le pilote Red Hat / Daynix UsbDk permet à `libusb-1.0` de capturer directement le port USB en mode BootROM sans écraser les pilotes de ports COM de Windows.

### Étape 1 : Déverrouillage Bootloader & Bypass FRP (Mode BROM)
- **Script :** `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat` (ou option `[2]` du menu).
- **Protocole :**
  1. Éteindre le téléphone (maintenir `POWER` 10 à 15 secondes).
  2. Maintenir `[VOLUME HAUT]` + `[VOLUME BAS]`.
  3. Brancher le câble USB relié au PC.
  4. Dès le premier message mtkclient, relâcher les boutons.
- **Commande atomique exécutée :**
  ```cmd
  python "..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"
  ```
- **Résultat :** Partition `seccfg` réécrite en mode déverrouillé (`lock_state = 0x03`), partition `frp` formatée (verrou de compte Google supprimé), partitions de chiffrement vidées, et réinitialisation de l'appareil.

### Étape 2 : Flash du Custom Recovery & Neutralisation AVB (Mode Fastboot)
- **Script :** `1_FLASHER_RECOVERY_ET_VBMETA.bat` (ou option `[3]` du menu).
- **Protocole :**
  1. Démarrer en mode Fastboot en maintenant `[VOLUME BAS]` + `[POWER]`.
  2. Brancher le câble USB.
  3. Lancer le script.
- **Commandes Fastboot exécutées :**
  ```cmd
  ..\bin\fastboot.exe --disable-verity --disable-verification flash vbmeta "recovery\vbmeta.img"
  ..\bin\fastboot.exe flash recovery "recovery\recovery.img"
  ..\bin\fastboot.exe reboot recovery
  ```
- **Protection anti-écrasement :** Le redémarrage immédiat vers le recovery (`reboot recovery`) empêche le script de démarrage stock MIUI `/system/bin/install-recovery.sh` d'écraser le custom recovery par le recovery d'usine.

### Étape 3 : Déploiement Custom ROM 64-bit & Root Magisk
- **Script :** `2_INSTALLER_ROM_64BIT_ET_ROOT.bat` (ou option `[4]` du menu).
- **Actions dans le Recovery (OrangeFox / TWRP) :**
  1. **Format Data (Impératif) :** `Wipe` > `Format Data` > taper `yes`. Supprime le chiffrement propriétaire MIUI.
  2. **Copie automatique ADB :** Le script copie les archives `.zip` présentes dans `roms\` ainsi que `Magisk-v26.4.apk` (copié sous `/sdcard/Magisk-v26.4.zip`).
  3. **Flash :** Installer la ROM 64-bit (`crDroidAndroid-13.0-blossom-OFFICIAL.zip` ou équivalent), puis installer `Magisk-v26.4.zip`.
  4. **Reboot System :** Démarrer sous Android 13.

### Étape 4 : Vérification Finale du Système sous Android
- **Script :** Option `[5]` du menu interactif ou phase de contrôle intégrée dans l'étape 2.

---

## 6. Commandes Exactes de Validation Système (ADB)

Une fois le téléphone démarré et le **Débogage USB** activé dans les options pour développeurs :

### 6.1 Validation de l'Architecture CPU 64-bit
Exécuter :
```cmd
..\bin\adb.exe shell getprop ro.product.cpu.abi
```
- **Résultat Conforme :**
  ```
  arm64-v8a
  ```
- **Critère de Rejet :** Si la commande retourne `armeabi-v7a`, le terminal fonctionne toujours avec la pile logicielle 32-bit d'origine.

Vérification complémentaire du noyau Linux :
```cmd
..\bin\adb.exe shell uname -m
```
- **Résultat Conforme :** `aarch64`

### 6.2 Validation des Privilèges Superutilisateur Root
Exécuter :
```cmd
..\bin\adb.exe shell su -c "id"
```
- **Résultat Conforme :**
  ```
  uid=0(root) gid=0(root) groups=0(root)... context=u:r:magisk:s0
  ```
- **Critère de Rejet :** Tout retour contenant `su: not found`, `Permission denied` ou un uid différent de 0 indique une absence de root opérationnel.

Vérification de la version du démon Magisk :
```cmd
..\bin\adb.exe shell su -c "magisk -v"
```
- **Résultat Conforme :** `26.4:MAGISK`

---

## 7. Dépannage & Cas Particuliers

1. **Le téléphone démarre en boucle sur l'écran d'avertissement dm-verity :**
   - Comportement normal après déverrouillage BROM. Appuyez une fois sur le bouton `POWER` pour poursuivre le démarrage, ou flashez `vbmeta.img` avec `--disable-verity --disable-verification`.
2. **Le mode BROM ne se déclenche pas lors du branchement USB :**
   - Assurez-vous que le téléphone est éteint à 100% (pas en veille). Maintenez `POWER` pendant 15 secondes.
   - Branchez le câble USB directement sur les ports arrière de la carte mère (évitez les hubs USB et les façades de boîtier).
   - Maintenez fermement `[VOLUME HAUT]` et `[VOLUME BAS]` **avant** et **pendant** l'insertion du câble.
3. **Le tactile ne répond pas dans le Custom Recovery :**
   - Le Redmi 10A utilise différents contrôleurs d'écran (Tianma, Huaxing, Novatek). La version de recovery incluse intègre les pilotes d'affichage multi-fournisseurs. Si un blocage survient, connectez une souris USB via un adaptateur OTG ou utilisez les touches physiques de volume pour naviguer.
