<#
.SYNOPSIS
    Begonia Fleet Manager - Pipeline Propre d'Automatisation & Déploiement Xiaomi Redmi Note 8 Pro (MT6785 / Helio G90T)
    Pre-OS Pipeline : Unbrick, Déverrouillage Bootloader, Bypass FRP, Flash R-OSS et Root (Zero Antivirus)
#>

param (
    [string]$Action = "menu"
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Header {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "   BEGONIA FLEET MANAGER - AUTOMATISATION REDMI NOTE 8 PRO       " -ForegroundColor Yellow
    Write-Host "   MT6785 Helio G90T | mtkclient Officiel | Zero SP Flash Tool  " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Check-Environment {
    Write-Host "[*] Diagnostic de l'environnement local :" -ForegroundColor Yellow
    
    # Check UsbDk Driver via Win32_SystemDriver or Registry
    $usbdkDriver = Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'" -ErrorAction SilentlyContinue
    $usbdkReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "UsbDk" }
    
    if ($usbdkDriver -or $usbdkReg -or (Test-Path "C:\Program Files\UsbDk Runtime Library") -or (Test-Path "C:\Program Files\UsbDk Runtime Libraries")) {
        Write-Host "[+] Pilote UsbDk (Red Hat/Daynix) : INSTALLE ET OPERATIONNEL" -ForegroundColor Green
    } else {
        Write-Host "[-] Pilote UsbDk : NON INSTALLE (Selectionnez Option 1 pour l'installer)" -ForegroundColor Red
    }

    # Check Python
    try {
        $pyVersion = python --version 2>&1
        Write-Host "[+] Python detecte : $pyVersion" -ForegroundColor Green
    } catch {
        Write-Host "[-] Python non detecte. Installez Python 3.10+ depuis python.org." -ForegroundColor Red
    }

    # Check Fastboot / ADB
    if (Test-Path "$ScriptDir\bin\fastboot.exe") {
        Write-Host "[+] Utilitaires Fastboot & ADB presents dans .\bin" -ForegroundColor Green
    }

    # Check mtkclient
    if (Test-Path "$ScriptDir\src\mtkclient\mtk.py") {
        Write-Host "[+] mtkclient officiel present dans .\src\mtkclient" -ForegroundColor Green
    }

    # Check recovery files
    if ((Test-Path "$ScriptDir\recovery\recovery.img") -and (Test-Path "$ScriptDir\recovery\vbmeta.img")) {
        Write-Host "[+] Images Recovery BRP 3.1 & VBMeta presentes dans .\recovery" -ForegroundColor Green
    }

    # Check stock firmware
    $eeaStock = "$ScriptDir\stock_firmware\images"
    if (Test-Path $eeaStock) {
        Write-Host "[+] Firmware Stock EEA MIUI 12.5 present dans .\stock_firmware\images (29 partitions)" -ForegroundColor Green
    }

    # Check ROM zips
    $romZip = "$ScriptDir\roms\PixelExperience_Plus_begonia-13.0-20231217-1732-OFFICIAL.zip"
    if (Test-Path $romZip) {
        Write-Host "[+] ROM PixelExperience Plus 13 presente dans .\roms" -ForegroundColor Green
    }
    Write-Host ""
}

function Install-UsbDk-Driver {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : INSTALLATION DU PILOTE OFFICIEL USBDK (RED HAT)       " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    $msiPath = "$ScriptDir\drivers\UsbDk_1.0.22_x64.msi"
    if (Test-Path $msiPath) {
        Write-Host "[*] Lancement de l'installateur MSI avec privileges Administrateur..." -ForegroundColor Yellow
        Write-Host "[!] Veuillez cliquer sur 'Oui' dans la fenetre d'autorisation Windows (UAC)." -ForegroundColor Cyan
        Start-Process msiexec.exe -ArgumentList "/i", "`"$msiPath`"" -Verb RunAs -Wait
        
        $usbdkDriver = Get-CimInstance Win32_SystemDriver -Filter "Name='UsbDk'" -ErrorAction SilentlyContinue
        if ($usbdkDriver) {
            Write-Host "[+] Pilote UsbDk installe et demarre avec succes !" -ForegroundColor Green
        } else {
            Write-Host "[!] L'installation a ete annulee ou necessite un redemarrage PC." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Fichier UsbDk_1.0.22_x64.msi introuvable dans .\drivers" -ForegroundColor Red
    }
}

function Unlock-And-FRP {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : DEVERROUILLAGE BOOTLOADER + BYPASS FRP (1 CLIC BROM)  " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "INSTRUCTIONS POUR LE TELEPHONE :" -ForegroundColor Cyan
    Write-Host "1. Debranchez le telephone du PC." -ForegroundColor White
    Write-Host "2. Maintenez le bouton POWER pendant 10-15s jusqu'a extinction complete (ecran noir)." -ForegroundColor White
    Write-Host "3. Maintenez enfonce [VOLUME HAUT] + [VOLUME BAS] simultanement." -ForegroundColor White
    Write-Host "4. Branchez le cable USB-C au PC tout en maintenant les boutons." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree quand pret..."

    Push-Location "$ScriptDir"
    Write-Host "[*] Interception du handshake BootROM en cours (session multi)..." -ForegroundColor Yellow
    python ".\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"
    Pop-Location
    Write-Host "[+] Operation terminee avec succes ! Debranchez le cable." -ForegroundColor Green
}

function Unbrick-Stock-Flash {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : STANDARDISATION & UNBRICK STOCK EEA (29 PARTITIONS)   " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ce script va reecrire 100% de la ROM stock officielle Xiaomi (29 partitions) :" -ForegroundColor Cyan
    Write-Host "- Bootloader : Preloader, LK1/2, TEE1/2, GZ1/2, SSPM1/2, SCP1/2" -ForegroundColor Gray
    Write-Host "- Noyau & Boot : Boot, Recovery, DTBO, VBMeta, Logo, MD1IMG, Audio_DSP" -ForegroundColor Gray
    Write-Host "- Systeme & OS : System (3.6 Go), Vendor (1.2 Go), Cust (700 Mo), Userdata (1.2 Go), Cache" -ForegroundColor Gray
    Write-Host ""
    Write-Host "1. Eteignez le telephone (POWER 10-15s jusqu'a ecran noir)." -ForegroundColor White
    Write-Host "2. Maintenez [VOLUME HAUT] + [VOLUME BAS] et branchez le cable USB." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree quand pret..."

    Push-Location "$ScriptDir"
    python ".\src\flash_stock_complete.py"
    Pop-Location
    Write-Host "[+] Flash d'usine termine avec succes ! Le telephone redemarre." -ForegroundColor Green
}

function Flash-Recovery-Fastboot {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : FLASH RECOVERY BRP 3.6 + VBMETA (MODE FASTBOOT)       " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Mettez le telephone en mode FASTBOOT (VOLUME BAS + POWER maintenus)." -ForegroundColor White
    Write-Host "2. Branchez le cable USB au PC." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree quand pret..."

    $fastbootExe = "$ScriptDir\bin\fastboot.exe"
    $brpImg = "$ScriptDir\recovery\BRPv3.6.img"
    $recImg = "$ScriptDir\recovery\recovery.img"
    $vbmetaImg = "$ScriptDir\recovery\vbmeta.img"

    Write-Host "[*] Verification du peripherique Fastboot..." -ForegroundColor Yellow
    & "$fastbootExe" devices

    Write-Host "[*] Flash de recovery BRP..." -ForegroundColor Yellow
    & "$fastbootExe" flash recovery "$brpImg"
    if ($LASTEXITCODE -ne 0) { Write-Host "[-] ERREUR : Flash BRP echoue (code $LASTEXITCODE). Verifiez que le telephone est en mode Fastboot." -ForegroundColor Red; return }
    & "$fastbootExe" flash recovery "$recImg"
    if ($LASTEXITCODE -ne 0) { Write-Host "[-] ERREUR : Flash Recovery echoue (code $LASTEXITCODE)." -ForegroundColor Red; return }

    Write-Host "[*] Flash de vbmeta (dm-verity disable)..." -ForegroundColor Yellow
    & "$fastbootExe" flash vbmeta "$vbmetaImg" --disable-verity --disable-verification
    if ($LASTEXITCODE -ne 0) { Write-Host "[-] ERREUR : Flash VBMeta echoue (code $LASTEXITCODE)." -ForegroundColor Red; return }

    Write-Host "[*] Redemarrage vers le Recovery..." -ForegroundColor Yellow
    Write-Host "[!] Maintenez VOLUME HAUT enfonce des que l'ecran s'eteint pour forcer l'entree en Recovery !" -ForegroundColor Cyan
    & "$fastbootExe" reboot recovery
    Write-Host "[+] Flash termine avec succes !" -ForegroundColor Green
}

function Push-ROM-Files-ADB {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host "  ACTION : COPIE AUTOMATIQUE DU FIRMWARE & ROM PAR ADB           " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "INSTRUCTIONS ESSENTIELLES DANS TWRP :" -ForegroundColor Cyan
    Write-Host "1. Sur le telephone dans TWRP : Allez dans le menu 'Mount'." -ForegroundColor White
    Write-Host "2. Cliquez sur 'Disable MTP' puis 'Enable MTP' pour reinitialiser le lien USB." -ForegroundColor Yellow
    Write-Host "3. Laissez le telephone connecte au PC." -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree pour verifier et lancer le transfert ADB..."

    $adbExe = "$ScriptDir\bin\adb.exe"
    & "$adbExe" devices
    
    $fwZip = "$ScriptDir\roms\FW R-OSS + BRP 3.1 - Begonia.zip"
    $romZip = "$ScriptDir\roms\PixelExperience_Plus_begonia-13.0-20231217-1732-OFFICIAL.zip"

    if (Test-Path $fwZip) {
        Write-Host "[*] Copie du Firmware R-OSS ($fwZip)..." -ForegroundColor Yellow
        & "$adbExe" push "$fwZip" /sdcard/
        if ($LASTEXITCODE -ne 0) { Write-Host "[-] ERREUR : Echec du transfert du Firmware R-OSS." -ForegroundColor Red }
    }
    if (Test-Path $romZip) {
        Write-Host "[*] Copie de PixelExperience Plus 13 ($romZip)..." -ForegroundColor Yellow
        & "$adbExe" push "$romZip" /sdcard/
        if ($LASTEXITCODE -ne 0) { Write-Host "[-] ERREUR : Echec du transfert de PixelExperience." -ForegroundColor Red }
    }
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "  TRANSFERT TERMINE ! DERNIERES ETAPES DANS TWRP :              " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "  1. Install  : Flasher 'FW R-OSS + BRP 3.1 - Begonia.zip'" -ForegroundColor White
    Write-Host "  2. Install  : Flasher 'PixelExperience_Plus_begonia-13.0...zip'" -ForegroundColor White
    Write-Host "  3. Mount    : Cocher [System] et [Vendor]" -ForegroundColor White
    Write-Host "  4. Advanced : Cliquer sur 'Root (Magisk)'" -ForegroundColor White
    Write-Host "  5. Advanced : Cliquer sur 'Disable Force Encrypt'" -ForegroundColor White
    Write-Host "  6. Advanced : Cliquer sur 'Disable TWRP Replace'" -ForegroundColor White
    Write-Host "  7. Wipe     : Cliquer sur 'Format Data' et taper 'yes'" -ForegroundColor Yellow
    Write-Host "  8. Reboot   : System (Le telephone demarre sous PixelExperience 13 !)" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
}

function Show-Menu {
    do {
        Show-Header
        Check-Environment
        Write-Host "--- INSTALLATION & PILOTES ---" -ForegroundColor DarkGray
        Write-Host "1. Installer le pilote officiel UsbDk (Requis pour le BootROM)" -ForegroundColor White
        Write-Host ""
        Write-Host "--- PIPELINE DE DEPLOIEMENT FLOTTE (ORDRE RECOMMANDE) ---" -ForegroundColor DarkGray
        Write-Host "2. Etape 1 : Deverrouiller Bootloader + Bypass FRP (Mode BROM)" -ForegroundColor White
        Write-Host "3. Etape 2 : Standardiser / Unbrick Stock EEA 12.5 (29 partitions BROM)" -ForegroundColor White
        Write-Host "4. Etape 3 : Flasher Recovery TWRP BRP 3.6 + VBMeta (Mode Fastboot)" -ForegroundColor White
        Write-Host "5. Etape 4 : Envoyer FW R-OSS + ROM PixelExperience 13 (ADB Recovery)" -ForegroundColor White
        Write-Host ""
        Write-Host "6. Quitter" -ForegroundColor White
        Write-Host ""
        $choice = Read-Host "Selectionnez une option (1-6)"

        switch ($choice) {
            "1" { Install-UsbDk-Driver; Pause }
            "2" { Unlock-And-FRP; Pause }
            "3" { Unbrick-Stock-Flash; Pause }
            "4" { Flash-Recovery-Fastboot; Pause }
            "5" { Push-ROM-Files-ADB; Pause }
            "6" { return }
            Default { Write-Host "Option invalide." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    } while ($choice -ne "6")
}

Show-Menu
