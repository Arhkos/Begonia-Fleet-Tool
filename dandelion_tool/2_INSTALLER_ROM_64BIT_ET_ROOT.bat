@echo off
chcp 65001 >nul
title 2. INSTALLATION CUSTOM ROM 64-BIT ET ROOT MAGISK - REDMI 10A

echo =====================================================================
echo    REDMI 10A (DANDELION/BLOSSOM) - DEPLOIEMENT ROM 64-BIT ^& ROOT
echo    Migration 32-bit (armeabi-v7a) vers 64-bit Natif (arm64-v8a)
echo =====================================================================
echo.

echo =====================================================================
echo    [i] CONTEXTE TECHNIQUE - TRANSITION ARCHITECTURALE 64-BIT :
echo    Le SoC MediaTek Helio G25 (MT6762G) integre 8 coeurs ARM Cortex-A53
echo    parfaitement capables d'operer en mode 64-bit ARMv8-A (aarch64).
echo    Sur MIUI 12.5 stock, Xiaomi a bride l'espace utilisateur en 32-bit
echo    (armeabi-v7a) avec un IPC Binder 32-bit pour les variantes 2 Go.
echo.
echo    Sur votre Redmi 10A (3 Go de RAM), ce bridge est contre-productif.
echo    Ce script automatise la copie de la ROM Custom 64-bit unifiee
echo    (crDroid 9 / LineageOS 20) et du binaire Magisk v26+ pour liberer
echo    les 3 Go de RAM et obtenir une execution 64-bit native.
echo =====================================================================
echo.

echo ETAPE A : DETECTION DU PERIPHERIQUE EN RECOVERY
echo  - Dans le Recovery crDroid :
echo    1. Formatage prealable [si transition MIUI stock] :
echo       Allez dans 'Factory reset' ^> 'Format data / factory reset' ^> valider 'Format data'.
echo    2. Passage en mode Sideload :
echo       Allez dans 'Apply update' ^> 'Apply from ADB'.
echo  - Reliez le cable USB au PC.
echo.
echo Verification des peripheriques ADB connectes...
"%~dp0..\bin\adb.exe" devices
echo.

set "ADB_STATE=non_detecte"
for /f "tokens=*" %%s in ('"%~dp0..\bin\adb.exe" get-state 2^>nul') do set "ADB_STATE=%%s"
echo [+] Etat de la connexion ADB detecte : %ADB_STATE%
echo.

rem Recherche de la ROM dans roms\ [en excluant les archives Magisk]
set "ROM_FILE="
set "ROM_NAME="
for %%f in ("%~dp0roms\*.zip") do (
    echo "%%~nxf" | findstr /i /v "Magisk" >nul
    if not errorlevel 1 (
        set "ROM_FILE=%%f"
        set "ROM_NAME=%%~nxf"
    )
)

rem Detection du paquet Magisk pour le root
set "MAGISK_FILE="
set "MAGISK_NAME="
if exist "%~dp0roms\Magisk-v30.7.zip" (
    set "MAGISK_FILE=%~dp0roms\Magisk-v30.7.zip"
    set "MAGISK_NAME=Magisk-v30.7.zip"
) else if exist "%~dp0roms\Magisk-v30.7.apk" (
    set "MAGISK_FILE=%~dp0roms\Magisk-v30.7.apk"
    set "MAGISK_NAME=Magisk-v30.7.apk"
) else if exist "%~dp0roms\Magisk-v26.4.apk" (
    set "MAGISK_FILE=%~dp0roms\Magisk-v26.4.apk"
    set "MAGISK_NAME=Magisk-v26.4.apk"
) else if exist "%~dp0roms\Magisk-v26.4.zip" (
    set "MAGISK_FILE=%~dp0roms\Magisk-v26.4.zip"
    set "MAGISK_NAME=Magisk-v26.4.zip"
)

echo Options disponibles :
echo  [1] Installer la ROM 64-bit [Sideload automatique ou Push]
echo  [2] Installer le Root Magisk [Sideload dans le Recovery]
echo  [3] Verifier l'architecture 64-bit et le Root [apres demarrage Android]
echo.
set /p CHOIX_ETAPE="Votre choix [1/2/3] (defaut=1) : "
if "%CHOIX_ETAPE%"=="2" goto FLASH_MAGISK
if "%CHOIX_ETAPE%"=="3" goto VERIFICATION_SYSTEME

:COPIE_FICHIERS
echo.
echo =====================================================================
echo    ETAPE B : INSTALLATION DE LA CUSTOM ROM 64-BIT
echo =====================================================================
echo.

if not defined ROM_FILE (
    echo [!] Aucune archive ROM .zip detectee dans .\roms\.
    echo     Consultez .\roms\README_ROMS.md pour telecharger crDroid ou LineageOS.
    pause
    goto FIN
)

echo [*] ROM detectee : "%ROM_NAME%"
echo.

if "%ADB_STATE%"=="sideload" (
    echo [+] Peripherique detecte en mode ADB SIDELOAD !
    echo [*] Demarrage du transfert via 'adb sideload' [patientez environ 1 a 2 minutes]...
    "%~dp0..\bin\adb.exe" sideload "%ROM_FILE%"
    if errorlevel 1 (
        echo.
        echo [-] Echec du transfert ADB Sideload.
    ) else (
        echo.
        echo [+] TRANSFERT DE LA ROM CRDROID TERMINE AVEC SUCCES !
    )
) else (
    echo [*] Envoi de la ROM vers /sdcard/ via ADB Push...
    "%~dp0..\bin\adb.exe" push "%ROM_FILE%" /sdcard/
    if errorlevel 1 (
        echo.
        echo [!] La copie Push n'a pas pu aboutir.
        echo     Dans le Recovery crDroid, passez en mode Sideload :
        echo     'Apply update' ^> 'Apply from ADB', puis relancez ce script [Option 1].
    ) else (
        echo [+] Copie terminee avec succes sur /sdcard/ !
    )
)

echo.
echo =====================================================================
echo    INSTRUCTIONS FINALES DANS LE RECOVERY CRDROID :
echo =====================================================================
echo  1. Root Magisk immediat [optionnel] :
echo     - Si le Recovery demande 'Install additional packages', choisissez 'Yes'.
echo     - Ou revenez au menu principal : 'Apply update' ^> 'Apply from ADB'
echo       puis relancez ce script en choisissant l'Option 2 [Magisk].
echo     - Si le message 'Signature verification failed. Install anyway?' s'affiche :
echo       Selectionnez 'Yes' [comportement standard pour Magisk].
echo.
echo  2. Formatage des donnees utilisateur [Anti-bootloop si premiere installation] :
echo     - Allez dans 'Factory reset' ^> 'Format data / factory reset'.
echo.
echo  3. Redemarrage :
echo     - Selectionnez 'Reboot system now'.
echo     - Laissez demarrer [premier boot : 2 a 3 minutes].
echo =====================================================================
echo.
set /p DEMANDE_MAGISK="Voulez-vous flasher Magisk maintenant en mode Sideload ? (O/N) : "
if /i "%DEMANDE_MAGISK%"=="O" goto FLASH_MAGISK
goto FIN

:FLASH_MAGISK
echo.
echo =====================================================================
echo    FLASH DU PAQUET ROOT MAGISK [MODE SIDELOAD]
echo =====================================================================
echo.
if not defined MAGISK_FILE (
    echo [-] Paquet Magisk introuvable dans .\roms\.
    pause
    goto FIN
)

echo Assurez-vous que le telephone est sur l'ecran 'Apply from ADB' [Sideload].
echo Fichier Magisk cible : "%MAGISK_NAME%"
echo.
pause

echo [*] Envoi de Magisk via ADB Sideload...
"%~dp0..\bin\adb.exe" sideload "%MAGISK_FILE%"
if errorlevel 1 (
    echo [-] Echec du flash de Magisk.
) else (
    echo [+] Magisk injecte avec succes !
)
echo.
echo [!] NOTE : Si le Recovery affiche "Signature verification failed. Install anyway?",
echo     selectionnez "Yes" sur l'ecran du telephone.
echo.
pause
goto FIN

:VERIFICATION_SYSTEME
echo.
echo =====================================================================
echo    ETAPE C : CONTROLE AUTOMATISE DE L'ARCHITECTURE 64-BIT ^& DU ROOT
echo =====================================================================
echo.
echo [*] Attente de la reponse ADB...
"%~dp0..\bin\adb.exe" wait-for-device

echo.
echo [1/2] Test de l'Architecture CPU (ro.product.cpu.abi)...
set CURRENT_ABI=inconnu
for /f "tokens=*" %%a in ('"%~dp0..\bin\adb.exe" shell getprop ro.product.cpu.abi 2^>nul') do set CURRENT_ABI=%%a

echo     Valeur retournee par l'OS : %CURRENT_ABI%
if /i "%CURRENT_ABI%"=="arm64-v8a" (
    echo [+] VALIDATION CONFORME : Le systeme tourne bien en 64-bit natif [arm64-v8a] !
) else (
    echo [-] ATTENTION : Valeur non attendue. Recu '%CURRENT_ABI%' au lieu de 'arm64-v8a'.
    echo     Verifiez que la Custom ROM 64-bit a ete correctement installee.
)

echo.
echo [2/2] Test des Privileges Superutilisateur Root (su -c id)...
set ROOT_OUTPUT=non_defini
for /f "tokens=*" %%b in ('call "%~dp0..\bin\adb.exe" shell su -c id 2^>nul') do set ROOT_OUTPUT=%%b

echo     Reponse de la commande : %ROOT_OUTPUT%
echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul
if %errorlevel% equ 0 (
    echo [+] VALIDATION CONFORME : Privileges root obtenus avec succes [uid=0] !
) else (
    echo [-] ATTENTION : Privilege root non detecte ou demande refusee.
    echo     Verifiez que l'application Magisk est installee et que le superutilisateur est autorise.
)

:FIN
echo.
echo =====================================================================
echo    PROCEDURE TERMINEE !
echo =====================================================================
pause
