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

## 5. Déroulement Chronologique du Pipeline (Éprouvé et Validé)

### Étape 0 : Installation du Pilote UsbDk
- **Action :** Exécuter `..\drivers\UsbDk_1.0.22_x64.msi` (installateur Red Hat / Daynix).
- **Utilité :** Capture directe du contrôleur USB pour le handshake BROM de MediaTek via `libusb-1.0`.

### Étape 1 : Déverrouillage Bootloader & Bypass Matériel RPMB (Mode BROM)
- **Script :** `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat` (exécute `unlock_dandelion.py`).
- **Problématique résolue :** Sur les Little Kernel récents (mai 2023+, `tokenversion: 2`), Xiaomi stocke une signature magic `Jz8PNRUF` dans la zone **RPMB** de l'eMMC. Même après un `seccfg unlock`, le bootloader restaurait `unlocked: no` (`lks = 1`) au démarrage.
- **Protocole :**
  1. Éteindre complètement le téléphone (`POWER` 10 à 15s).
  2. Lancer le script d'écoute BROM.
  3. Maintenir fermement `[VOLUME HAUT]` + `[VOLUME BAS]` et brancher le câble USB (port USB 2.0 de préférence).
  4. Relâcher les boutons dès la détection.
- **Actions automatisées par `unlock_dandelion.py` :**
  - Sauvegarde de sécurité de la partition `lk` et lecture de la `RPMB` (1 Mo / 16 Mo).
  - Détection automatique de la signature `Jz8PNRUF` à l'offset `0xE00000` (secteur 57344).
  - Effacement ciblé des 4 secteurs magic RPMB (1024 octets) et re-lecture de vérification (confirmée à 0x00).
  - Écriture du déverrouillage `seccfg` (`ATTR_UNLOCK`).
  - Formatage sécurisé des partitions `frp`, `metadata`, `userdata`, `md_udc`.
  - Redémarrage et vérification immédiate :
    ```cmd
    fastboot getvar unlocked   -> unlocked: yes
    fastboot oem lks           -> lks = 0
    ```

### Étape 2 : Extraction et Flash des Images Certifiées crDroid (Mode Fastboot)
- **Script :** `flash_crdroid_recovery.bat` (ou commandes manuelles).
- **Origine des images :** L'archive officielle de la ROM (`crDroidAndroid-*-blossom-*.zip`) contient directement dans son zip les images certifiées et synchronisées avec le noyau :
  - `recovery.img` (Recovery officiel crDroid pour blossom)
  - `boot.img` & `dtbo.img` (Noyau 64-bit et arbre de périphériques)
  - `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img` (avec AVB désactivé `flags=0x3`)
- **Commandes Fastboot exécutées :**
  ```cmd
  ..\bin\fastboot.exe --disable-verity --disable-verification flash vbmeta "recovery\crdroid\vbmeta.img"
  ..\bin\fastboot.exe flash vbmeta_system "recovery\crdroid\vbmeta_system.img"
  ..\bin\fastboot.exe flash vbmeta_vendor "recovery\crdroid\vbmeta_vendor.img"
  ..\bin\fastboot.exe flash boot "recovery\crdroid\boot.img"
  ..\bin\fastboot.exe flash dtbo "recovery\crdroid\dtbo.img"
  ..\bin\fastboot.exe flash recovery "recovery\crdroid\recovery.img"
  ..\bin\fastboot.exe reboot recovery
  ```

### Étape 3 : Déploiement de la ROM crDroid via ADB Sideload
- **Actions dans le Recovery crDroid :**
  1. **Formatage préalable :** `Factory reset` > `Format data / factory reset` > valider `Format data`.
  2. **Passage en mode Sideload :** `Apply update` > `Apply from ADB`.
  3. **Transfert de la ROM depuis le PC :**
     ```cmd
     ..\bin\adb.exe sideload dandelion_tool\roms\crDroidAndroid-*-blossom-*.zip
     ```
  4. **Formatage userdata final (Anti-Bootloop) :**
     Une fois le sideload terminé, reformater `userdata` (`Format data` dans le recovery ou `fastboot erase userdata` / `erase metadata`) pour que la table de chiffrement soit 100% propre pour la nouvelle ROM.
  5. **Démarrage :** `Reboot system now`. Le téléphone démarre sur l'assistant de bienvenue crDroid.

### Étape 4 : Activation du Débogage USB & Root Magisk
1. **Accès au bureau Android :** Passer l'assistant initial crDroid.
2. **Débogage USB :**
   - Paramètres > À propos du téléphone > tapoter 7 fois sur *Numéro de build*.
   - Paramètres > Système > Options pour les développeurs > activer *Débogage USB*.
   - Valider la popup « Toujours autoriser depuis cet ordinateur ».
3. **Installation du Root :**
   - Installer l'application Magisk v30+ :
     ```cmd
     ..\bin\adb.exe install dandelion_tool\roms\Magisk-v30.7.apk
     ```
   - Injecter le binaire root dans le noyau via Recovery (`adb reboot recovery` > `Apply from ADB` > `adb sideload Magisk-v30.7.zip`) ou via l'option native *Rooted debugging* de crDroid.

---

## 6. Commandes Exactes de Validation Système (ADB)

Une fois le téléphone démarré avec le Débogage USB actif :

### 6.1 Validation de l'Architecture CPU 64-bit Native
Exécuter :
```cmd
..\bin\adb.exe shell getprop ro.product.cpu.abi
```
- **Résultat Conforme :**
  ```
  arm64-v8a
  ```

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

---

## 7. Dépannage & Retours d'Expérience Réels

1. **Bootloader reste à `unlocked: no` après mtkclient :**
   - **Cause :** Présence du magic RPMB à l'offset `0xE00000` (secteur 57344) vérifié par le Little Kernel.
   - **Solution :** Utiliser `unlock_dandelion.py` qui efface automatiquement les 4 secteurs magic RPMB et applique `seccfg unlock` dans la même session BROM.
2. **Le téléphone démarre sur le MIUI Recovery au lieu du Custom Recovery :**
   - **Cause :** Noyau de recovery trop ancien (ex. build 2020 pour Android 10) ou absence des tables `vbmeta_system` / `vbmeta_vendor`.
   - **Solution :** Flasher les images synchronisées extraites du zip crDroid (`vbmeta`, `vbmeta_system`, `vbmeta_vendor`, `boot`, `dtbo`, `recovery`).
3. **Bootloop sur le logo MI après flash de la ROM :**
   - **Cause :** Conflit de chiffrement sur la partition `userdata` ou tentative de patch avec une ancienne version de Magisk (v26) incompatible avec le format d'init d'Android 15/16.
   - **Solution :** Flasher le `boot.img` propre crDroid, exécuter `fastboot erase userdata` et `erase metadata`, puis utiliser Magisk v30+ certifié pour Android 15/16.
4. **Réinitialisation d'usine (Factory Reset) et persistance du Root :**
   - **Comportement :** Une réinitialisation d'usine depuis les menus Android n'efface QUE la partition `userdata`. La partition `boot` contenant le patch Magisk au niveau du noyau demeure 100% intacte.
   - **Résultat :** Le root est intégralement conservé. Le binaire `su` fonctionne toujours via ADB. Il suffit simplement de réinstaller l'application graphique via `adb install dandelion_tool\roms\Magisk-v30.7.apk` si l'interface utilisateur Magisk est souhaitée.

