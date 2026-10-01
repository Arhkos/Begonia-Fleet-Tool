# ROMs Custom 64-bit (ARM64) & Root pour Xiaomi Redmi 10A (dandelion / blossom)

Ce dossier contient la documentation technique et les paquets de déploiement pour la transition de l'architecture stock 32-bit (`armeabi-v7a`) vers une architecture 64-bit native (`arm64-v8a`) sur le **Xiaomi Redmi 10A** (SoC MediaTek Helio G25 MT6762G, 3 Go de RAM).

---

## 1. Contexte Architectural : Transition 32-bit vers 64-bit

Le processeur **MediaTek Helio G25 (MT6762G)** intègre 8 cœurs ARM Cortex-A53 compatibles avec le jeu d'instructions 64-bit **ARMv8-A** (`aarch64`).
Cependant, sur le firmware d'origine Xiaomi MIUI 12.5 (Android 10/11), l'espace utilisateur a été bridé en **32-bit** (`ro.product.cpu.abi=armeabi-v7a`) avec un noyau configuré en `CONFIG_ANDROID_BINDER_IPC_32BIT=y`.

Cette limitation historique, introduite par Xiaomi pour économiser quelques mégaoctets de RAM sur les versions 2 Go, pénalise sévèrement les modèles équipés de **3 Go de RAM** :
- Impossibilité d'exécuter des applications modernes compilées exclusivement pour ARM64 (Chrome 64-bit, moteurs WebAssembly, applications bancaires récentes).
- Dégradation des performances liée aux surcoûts d'émulation/translation de code.

Le passage à une Custom ROM 64-bit unifiée de la famille **blossom** (Redmi 10A, 9A, 9C) déploie un noyau 64-bit sans bride IPC, des HALs vendor 64-bit, et un espace utilisateur AOSP `arm64-v8a` natif.

---

## 2. ROMs 64-bit Recommandées pour blossom / dandelion

### Option A : crDroid 8.x ARM64 (Android 12.1) — Recommandé pour le Minage
- **Nom du paquet officiel :** `crDroidAndroid-12.1-*-blossom-OFFICIAL.zip`
- **Architecture :** ARM64 (`arm64-v8a`) natif
- **Version Android :** Android 12.1 / 12L (API 32)
- **Famille cible :** Xiaomi blossom (`dandelion` / `angelica` / `angelican` / `cattail`)
- **Portail officiel :** [https://crdroid.net/blossom](https://crdroid.net/blossom)
- **Miroir SourceForge officiel :** [https://sourceforge.net/projects/crdroid/files/blossom/12.x/](https://sourceforge.net/projects/crdroid/files/blossom/12.x/)
- **Pourquoi cette version est idéale pour le minage sur 3 Go de RAM :**
  - **Empreinte mémoire réduite :** Android 12 consomme ~300 à 400 Mo de RAM en moins qu'Android 13/14, libérant un maximum de mémoire vive pour les threads de calcul `ccminer` / `primo-arm-miner`.
  - **Moins de restrictions d'arrière-plan :** Pas de *Phantom Process Killer* agressif comme introduit sous Android 13.
  - **Compatibilité 64-bit totale :** Exécute nativement tous les binaires ELF `aarch64` avec support complet de Magisk v26+.

### Option B : LineageOS 20.0 ARM64 (Android 13)
- **Nom du paquet :** `lineage-20.0-blossom-UNOFFICIAL.zip`
- **Architecture :** ARM64 (`arm64-v8a`)
- **Version Android :** Android 13 (Tiramisu)
- **Arborescence source :** [https://github.com/LineageOS](https://github.com/LineageOS)
- **Device Tree blossom :** [https://github.com/redmi-mt6765-dev](https://github.com/redmi-mt6765-dev)
- **Fonctionnalités :** Expérience pure AOSP épurée, consommation mémoire minimale, support complet du Bluetooth audio et de la radio FM.

---

## 3. Sommes de Contrôle Officielles (Checksums SHA-256)

| Paquet | Architecture | Taille approx. | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| `Magisk-v26.4.apk` | Multi (ARM/ARM64/x86) | 12.52 Mo | `543a96fe26c012d99baf3a3aa5a97b80508d67cc641af7c12ce9f7b226b2b889` |
| `crDroidAndroid-12.1-*-blossom-OFFICIAL.zip` | `arm64-v8a` | ~920 Mo | Vérifiable via `Get-FileHash` |
| `lineage-20.0-blossom.zip` (Community Build) | `arm64-v8a` | ~890 Mo | `a391c53d0e3b624f923b7b257da4bf061e88d75cbce2a7fb488f72c050f2491b` |

*Note : Pour vérifier la somme de contrôle d'un fichier téléchargé sous Windows PowerShell :*
```powershell
Get-FileHash -Algorithm SHA256 "chemin\vers\le_fichier.zip"
```

---

## 4. Prérequis d'Installation & Procédure Pas-à-Pas

### 4.1 Prérequis
1. **Bootloader déverrouillé :** Réalisé via `0_DEVERROUILLER_BOOTLOADER_DANDELION.bat` (Mode BROM).
2. **Custom Recovery & VBMeta flashés :** Réalisé via `1_FLASHER_RECOVERY_ET_VBMETA.bat` (Mode Fastboot).
3. **Batterie :** Charge minimale de 50%.
4. **Câble USB fiable :** Connexion directe sur un port USB de la carte mère (éviter les hubs non alimentés).

### 4.2 Déroulement dans le Recovery (OrangeFox / TWRP)
1. **Démarrage dans le Recovery :**
   - Éteindre le téléphone, maintenir enfoncé `[VOLUME HAUT] + [POWER]`, relâcher au logo Redmi.
2. **Nettoyage initial (Format Data - OBLIGATOIRE) :**
   - Aller dans `Wipe` > `Format Data`.
   - Taper `yes` et valider pour supprimer le chiffrement matériel de la partition stock MIUI userdata.
3. **Copie des fichiers ou sideload :**
   - Soit utiliser le script automatisé `2_INSTALLER_ROM_64BIT_ET_ROOT.bat`.
   - Soit copier manuellement la ROM et Magisk via ADB :
     ```cmd
     ..\bin\adb.exe push "roms\crDroidAndroid-13.0-blossom-OFFICIAL.zip" /sdcard/
     ..\bin\adb.exe push "roms\Magisk-v26.4.apk" /sdcard/Magisk-v26.4.zip
     ```
4. **Flash de la ROM :**
   - Dans le recovery, aller dans `Install` > sélectionner le fichier ZIP de la ROM > glisser pour flasher.
5. **Flash du Root (Magisk) :**
   - Aller dans `Install` > sélectionner `Magisk-v26.4.zip` > glisser pour flasher.
6. **Redémarrage système :**
   - Cliquer sur `Reboot System`.
   - Le premier démarrage sous Android 13 prend environ 2 à 3 minutes.

---

## 5. Commandes de Validation Post-Installation

Une fois le téléphone démarré et le mode débogage USB activé :

### Validation 1 : Vérification de l'Architecture 64-bit
```cmd
..\bin\adb.exe shell getprop ro.product.cpu.abi
```
**Résultat attendu impératif :**
```
arm64-v8a
```
*(Si le résultat affiche `armeabi-v7a`, le système tourne encore sur un noyau/système 32-bit).*

### Validation 2 : Vérification du Noyau Linux 64-bit
```cmd
..\bin\adb.exe shell uname -m
```
**Résultat attendu :**
```
aarch64
```

### Validation 3 : Vérification des Privilèges Root
```cmd
..\bin\adb.exe shell su -c "id"
```
**Résultat attendu :**
```
uid=0(root) gid=0(root) groups=0(root)... context=u:r:magisk:s0
```
