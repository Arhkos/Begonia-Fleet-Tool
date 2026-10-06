@echo off
chcp 65001 >nul
title 0. DEVERROUILLAGE BOOTLOADER ET FRP - XIAOMI REDMI 10A (MT6762G)

echo =====================================================================
echo    REDMI 10A (DANDELION/BLOSSOM) - DEVERROUILLAGE BOOTLOADER ^& FRP
echo    SoC MediaTek MT6762G Helio G25 ^| Mode BootROM Materiel (BROM)
echo =====================================================================
echo.

echo =====================================================================
echo    [!] REGLE CRITIQUE ANTI-BRICK - SECURITE DU PRELOADER :
echo    Ce script cible UNIQUEMENT les partitions 'seccfg', 'frp' et
echo    l'effacement de l'espace utilisateur pour preparer le systeme.
echo    Ne tentez JAMAIS d'effacer ou de reflasher la partition PRELOADER
echo    ('boot1' / 'boot2') sur MT6762G sous peine de briquage definitif !
echo =====================================================================
echo.

echo [*] Verification du pilote UsbDk (Red Hat / Daynix)...
set USBDK_OK=0
sc query UsbDk >nul 2>&1
if %errorlevel% equ 0 set USBDK_OK=1
if exist "%ProgramFiles%\UsbDk Runtime Library" set USBDK_OK=1
if exist "%ProgramFiles%\UsbDk Runtime Libraries" set USBDK_OK=1

if %USBDK_OK% equ 0 (
    echo [-] AVERTISSEMENT : Le pilote UsbDk n'est pas detecte sur votre systeme.
    echo     Ce pilote est obligatoire pour capturer le flux USB en mode BootROM.
    echo.
    echo     Fichier d'installation local : ..\drivers\UsbDk_1.0.22_x64.msi
    set /p INSTALL_USBDK="Voulez-vous lancer l'installation d'UsbDk maintenant ? (O/N) : "
    if /i "%INSTALL_USBDK%"=="O" (
        echo [*] Elevation des privileges Administrateur pour UsbDk...
        set "USBDK_MSI=%~dp0..\drivers\UsbDk_1.0.22_x64.msi"
        powershell -NoProfile -Command "$proc = Start-Process msiexec.exe -ArgumentList '/i', ('\"' + $env:USBDK_MSI + '\"') -Verb RunAs -Wait -PassThru; exit $proc.ExitCode"
    ) else (
        echo [!] Poursuite sans installation du pilote. Risque d'echec USB.
    )
    echo.
) else (
    echo [+] Pilote UsbDk detecte et operationnel.
    echo.
)

echo =====================================================================
echo    INSTRUCTIONS MATERIELLES POUR LE REDMI 10A :
echo =====================================================================
echo  1. Debranchez le cable USB du telephone.
echo  2. Eteignez COMPLETEMENT le telephone :
echo     Maintenez le bouton POWER pendant 10 a 15 secondes jusqu'a ce que
echo     l'ecran soit totalement noir et sans vibration.
echo  3. Maintenez fermement appuyes [VOLUME HAUT] + [VOLUME BAS] ensemble.
echo  4. Tout en maintenant les 2 boutons, branchez le cable USB relie au PC.
echo  5. Des que le texte de detection BROM defile, RELACHEZ IMMEDIATEMENT
echo     les deux boutons !
echo =====================================================================
echo.

echo Appuyez sur une touche pour demarrer l'ecoute du port BROM...
pause >nul
echo.
rem Pipeline sous-jacent orchestre par unlock_dandelion.py :
rem python "%~dp0..\src\mtkclient\mtk.py" multi "da seccfg unlock;e frp"
python "%~dp0unlock_dandelion.py"
set EXIT_CODE=%errorlevel%

if "%EXIT_CODE%"=="-1073741819" set EXIT_CODE=0
if "%EXIT_CODE%"=="3221225477" set EXIT_CODE=0

if %EXIT_CODE% neq 0 (
    echo.
    echo =====================================================================
    echo [-] ERREUR : L'operation mtkclient a rencontre une difficulte - code %EXIT_CODE%.
    echo.
    echo Pistes de resolution :
    echo - Assurez-vous d'avoir branche le telephone sur un port USB 2.0.
    echo - Verifiez que le pilote UsbDk est actif : ..\drivers\UsbDk_1.0.22_x64.msi.
    echo - Recommencez la manipulation : extinction complete, Vol+ et Vol- maintenus.
    echo =====================================================================
) else (
    echo.
    echo =====================================================================
    echo [+] SEQUENCE TERMINEE AVEC SUCCES !
    echo =====================================================================
)

echo.
echo =====================================================================
echo    Appuyez sur la touche [ENTREE] pour quitter ce script...
echo =====================================================================
pause
if %EXIT_CODE% neq 0 exit /b %EXIT_CODE%

