<#
.SYNOPSIS
    Dandelion Fleet Manager - Pipeline d'Automatisation & Deploiement Xiaomi Redmi 10A (MT6762G Helio G25)
    Famille blossom (dandelion) : BROM Unlock, Fastboot Recovery/AVB Bypass, ROM 64-bit & Root Magisk
#>

param (
    [string]$Action = "menu"
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = Split-Path -Parent $ScriptDir

# Binaires partages du depot racine (Lecture seule)
$fastbootExe = "$WorkspaceRoot\bin\fastboot.exe"
$adbExe      = "$WorkspaceRoot\bin\adb.exe"
$mtkPy       = "$WorkspaceRoot\src\mtkclient\mtk.py"
$usbdkMsi    = "$WorkspaceRoot\drivers\UsbDk_1.0.22_x64.msi"

# Fichiers dedies au module dandelion_tool
$recImg      = "$ScriptDir\recovery\recovery.img"
$vbmetaImg   = "$ScriptDir\recovery\vbmeta.img"
$magiskApk   = "$ScriptDir\roms\Magisk-v26.4.apk"

function Show-Header {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "   DANDELION FLEET MANAGER - AUTOMATISATION XIAOMI REDMI 10A     " -ForegroundColor Yellow
    Write-Host "   MT6762G Helio G25 | Famille blossom | Migration 64-bit Natif  " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Check-Environment {
    Write-Host "[*] Diagnostic de l'environnement local :" -ForegroundColor Yellow

    # Verification pilote UsbDk
    $usbdkDriver = Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'" -ErrorAction SilentlyContinue
    $usbdkReg = Get-ItemProperty "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "UsbDk" }

    if ($usbdkDriver -or $usbdkReg -or (Test-Path "$env:ProgramFiles\UsbDk Runtime Library") -or (Test-Path "$env:ProgramFiles\UsbDk Runtime Libraries")) {
        Write-Host "[+] Pilote UsbDk (Red Hat/Daynix) : INSTALLE ET OPERATIONNEL" -ForegroundColor Green
    } else {
        Write-Host "[-] Pilote UsbDk : NON DETECTE (Requis pour le BootROM, option 1)" -ForegroundColor Red
    }

    # Verification Python
    try {
        $pyVersion = python --version 2>&1
        Write-Host "[+] Environnement Python detecte : $pyVersion" -ForegroundColor Green
    } catch {
        Write-Host "[-] Python non detecte dans le PATH." -ForegroundColor Red
    }

    # Verification binaires Fastboot & ADB
    if ((Test-Path $fastbootExe) -and (Test-Path $adbExe)) {
        Write-Host "[+] Binaires Fastboot & ADB presents dans ..\bin" -ForegroundColor Green
    } else {
        Write-Host "[-] Binaires Fastboot/ADB manquants dans ..\bin" -ForegroundColor Red
    }

    # Verification mtkclient
    if (Test-Path $mtkPy) {
        Write-Host "[+] Outil mtkclient officiel present dans ..\src\mtkclient" -ForegroundColor Green
    } else {
        Write-Host "[-] mtkclient introuvable dans ..\src\mtkclient" -ForegroundColor Red
    }

    # Verification fichiers Recovery & VBMeta
    if ((Test-Path $recImg) -and (Test-Path $vbmetaImg)) {
        Write-Host "[+] Custom Recovery & VBMeta AVB presents dans .\recovery" -ForegroundColor Green
    } else {
        Write-Host "[-] Fichiers recovery.img ou vbmeta.img manquants dans .\recovery" -ForegroundColor Red
    }

    # Verification paquets ROM / Magisk
    $romZips = Get-ChildItem -Path "$ScriptDir\roms" -Filter "*.zip" -ErrorAction SilentlyContinue
    if (Test-Path $magiskApk) {
        Write-Host "[+] Paquet Root Magisk v26.4 present dans .\roms" -ForegroundColor Green
    } else {
        Write-Host "[!] Paquet Magisk-v26.4.apk absent de .\roms" -ForegroundColor Yellow
    }

    if ($romZips.Count -gt 0) {
        Write-Host "[+] $($romZips.Count) archive(s) ROM .zip detectee(s) dans .\roms" -ForegroundColor Green
    } else {
        Write-Host "[!] Aucune archive ROM .zip dans .\roms (Consultez README_ROMS.md)" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Install-UsbDk-Driver {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : INSTALLATION DU PILOTE OFFICIEL USBDK (RED HAT)       " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    if (Test-Path $usbdkMsi) {
        Write-Host "[*] Lancement de l'installateur UsbDk avec privileges Administrateur..." -ForegroundColor Yellow
        Write-Host "[!] Veuillez valider la demande UAC Windows si necessaire." -ForegroundColor Cyan
        Start-Process msiexec.exe -ArgumentList "/i", "`"$usbdkMsi`"" -Verb RunAs -Wait

        $usbdkDriver = Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'" -ErrorAction SilentlyContinue
        if ($usbdkDriver -or (Test-Path "$env:ProgramFiles\UsbDk Runtime Library")) {
            Write-Host "[+] Pilote UsbDk installe et actif avec succes !" -ForegroundColor Green
        } else {
            Write-Host "[!] L'installation a ete annulee ou necessite un redemarrage du systeme." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[-] Fichier UsbDk introuvable : $usbdkMsi" -ForegroundColor Red
    }
}

function Unlock-And-FRP {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : DEVERROUILLAGE BOOTLOADER ^& BYPASS FRP (BROM MT6762G)" -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[!] REGLE CRITIQUE ANTI-BRICK :" -ForegroundColor Cyan
    Write-Host "    Ce script cible uniquement seccfg, frp et le formatage userdata." -ForegroundColor White
    Write-Host "    La partition PRELOADER (boot1/boot2) n'est JAMAIS modifiee." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "INSTRUCTIONS POUR LE REDMI 10A :" -ForegroundColor Cyan
    Write-Host "1. Debranchez le telephone du PC." -ForegroundColor White
    Write-Host "2. Eteignez completement le telephone (POWER 10-15s jusqu'a ecran noir)." -ForegroundColor White
    Write-Host "3. Maintenez fermement [VOLUME HAUT] + [VOLUME BAS] simultanement." -ForegroundColor White
    Write-Host "4. Branchez le cable USB au PC tout en maintenant les deux boutons." -ForegroundColor White
    Write-Host "5. Relachez les boutons des que le texte defile a l'ecran." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree quand pret..."

    Write-Host "[*] Interception du handshake BootROM en cours (session mtkclient multi)..." -ForegroundColor Yellow
    & python "$mtkPy" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] Operation terminee avec succes ! Bootloader deverrouille et FRP efface." -ForegroundColor Green
    } else {
        Write-Host "[-] ERREUR : Echec mtkclient (code $LASTEXITCODE). Verifiez le pilote UsbDk et le port USB." -ForegroundColor Red
    }
}

function Flash-Recovery-Fastboot {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : FLASH CUSTOM RECOVERY ^& DESACTIVATION AVB (FASTBOOT)  " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "INSTRUCTIONS POUR LE MODE FASTBOOT :" -ForegroundColor Cyan
    Write-Host "1. Eteignez le telephone." -ForegroundColor White
    Write-Host "2. Maintenez [VOLUME BAS] + [POWER] jusqu'a l'affichage de FASTBOOT." -ForegroundColor White
    Write-Host "3. Reliez le cable USB au PC." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree quand pret..."

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

    Write-Host "[*] Flash de vbmeta.img avec desactivation AVB 2.0 (dm-verity)..." -ForegroundColor Yellow
    & "$fastbootExe" --disable-verity --disable-verification flash vbmeta "$vbmetaImg"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] ERREUR lors du flash de VBMeta (code $LASTEXITCODE)." -ForegroundColor Red
        return
    }
    Write-Host "[+] VBMeta flashe et AVB neutralise avec succes !" -ForegroundColor Green

    Write-Host "[*] Flash du Custom Recovery ($recImg)..." -ForegroundColor Yellow
    & "$fastbootExe" flash recovery "$recImg"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] ERREUR lors du flash du Recovery (code $LASTEXITCODE)." -ForegroundColor Red
        return
    }
    Write-Host "[+] Custom Recovery flashe avec succes !" -ForegroundColor Green

    Write-Host "[*] Redemarrage direct vers le Custom Recovery..." -ForegroundColor Yellow
    Write-Host "[!] Maintenez [VOLUME HAUT] des extinction pour eviter l'ecrasement par MIUI !" -ForegroundColor Cyan
    & "$fastbootExe" reboot recovery
    Write-Host "[+] Commande de reboot executee. Le telephone demarre en recovery." -ForegroundColor Green
}

function Push-ROM-Files-ADB {
    # Mappe avec 2_INSTALLER_ROM_64BIT_ET_ROOT.bat (workflow adb push / sideload)
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : DEPLOIEMENT DE LA CUSTOM ROM 64-BIT ET DE MAGISK      " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "INSTRUCTIONS DANS LE CUSTOM RECOVERY (OrangeFox / TWRP) :" -ForegroundColor Cyan
    Write-Host "1. Sur le telephone, verifiez la connexion USB." -ForegroundColor White
    Write-Host "2. Si la detection echoue, allez dans 'Mount' > 'Disable MTP' puis 'Enable MTP'." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree pour verifier la liaison ADB..."

    & "$adbExe" devices

    # Recherche et envoi des ROMs
    $romFiles = Get-ChildItem -Path "$ScriptDir\roms" -Filter "*.zip" -ErrorAction SilentlyContinue
    foreach ($file in $romFiles) {
        Write-Host "[*] Envoi de $($file.Name) vers /sdcard/ ..." -ForegroundColor Yellow
        & "$adbExe" push "$($file.FullName)" /sdcard/
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[-] Avertissement lors de la copie de $($file.Name)." -ForegroundColor Red
        } else {
            Write-Host "[+] Copie terminee : $($file.Name)" -ForegroundColor Green
        }
    }

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

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "  ETAPES FINALES A REALISER DANS LE RECOVERY :                  " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "  1. Wipe     : 'Format Data' > taper 'yes' (Obligatoire transition stock)" -ForegroundColor Yellow
    Write-Host "  2. Install  : Flasher le fichier .zip de la Custom ROM 64-bit" -ForegroundColor White
    Write-Host "  3. Install  : Flasher '/sdcard/Magisk-v26.4.zip' pour le root 64-bit" -ForegroundColor White
    Write-Host "  4. Reboot   : System (Premier boot : 2 a 3 minutes)" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
}

function Verify-System-ADB {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : VERIFICATION ARCHITECTURE 64-BIT ^& ACCES ROOT        " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[*] Attente du telephone avec debogage USB active..." -ForegroundColor Yellow
    & "$adbExe" wait-for-device

    # 1. Verification de l'architecture
    Write-Host "[1/2] Controle de l'architecture (ro.product.cpu.abi)..." -ForegroundColor Yellow
    $abiRaw = & "$adbExe" shell getprop ro.product.cpu.abi 2>&1
    $abi = ($abiRaw | Out-String).Trim()
    Write-Host "      Valeur lue : $abi" -ForegroundColor White

    if ($abi -eq "arm64-v8a") {
        Write-Host "[+] ARCHITECTURE 64-BIT VALIDEE : Le systeme tourne sous arm64-v8a !" -ForegroundColor Green
    } else {
        Write-Host "[-] ECHEC ARCHITECTURE : Attendu 'arm64-v8a', recu '$abi'." -ForegroundColor Red
        Write-Host "    Le systeme tourne toujours en 32-bit (armeabi-v7a). Verifiez la ROM." -ForegroundColor Yellow
    }

    # 2. Verification de l'acces root
    Write-Host ""
    Write-Host "[2/2] Controle des privileges Root (su -c 'id')..." -ForegroundColor Yellow
    $rootRaw = & "$adbExe" shell su -c "id" 2>&1
    $rootOutput = ($rootRaw | Out-String).Trim()
    Write-Host "      Reponse de l'invite root : $rootOutput" -ForegroundColor White

    if ($rootOutput -match "uid=0\(root\)") {
        Write-Host "[+] PRIVILEGES ROOT VALIDES : Acces superutilisateur confirme (uid=0) !" -ForegroundColor Green
    } else {
        Write-Host "[-] ECHEC ROOT : Privilege root introuvable ou permission refusee." -ForegroundColor Red
        Write-Host "    Verifiez que Magisk a bien ete flashe et autorise dans l'application." -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-Menu {
    do {
        Show-Header
        Check-Environment
        Write-Host "--- INSTALLATION PILOTE ---" -ForegroundColor DarkGray
        Write-Host "1. Installer le pilote officiel UsbDk (Requis pour le BootROM)" -ForegroundColor White
        Write-Host ""
        Write-Host "--- PIPELINE D'AUTOMATISATION REDMI 10A (ORDRE CHRONOLOGIQUE) ---" -ForegroundColor DarkGray
        Write-Host "2. Deverrouiller Bootloader & FRP (Mode BROM MT6762G)" -ForegroundColor White
        Write-Host "3. Flasher Custom Recovery & Desactiver AVB (Mode Fastboot)" -ForegroundColor White
        Write-Host "4. Deployer Custom ROM 64-bit & Root (Copie ADB Recovery)" -ForegroundColor White
        Write-Host "5. Verifier Architecture 64-bit (arm64-v8a) & Root (uid=0) via ADB" -ForegroundColor White
        Write-Host ""
        Write-Host "6. Quitter" -ForegroundColor White
        Write-Host ""
        $choice = Read-Host "Selectionnez une option (1-6)"

        switch ($choice) {
            "1" { Install-UsbDk-Driver; Pause }
            "2" { Unlock-And-FRP; Pause }
            "3" { Flash-Recovery-Fastboot; Pause }
            "4" { Push-ROM-Files-ADB; Pause }
            "5" { Verify-System-ADB; Pause }
            "6" { return }
            Default { Write-Host "Option invalide." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    } while ($choice -ne "6")
}

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
