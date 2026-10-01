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
echo  1. Assurez-vous que le telephone est demarre en Custom Recovery (OrangeFox/TWRP).
echo  2. Branchez le cable USB au PC.
echo  3. Dans le recovery, allez dans 'Mount' : si necessaire, desactivez puis
echo     reactivez MTP pour rafraichir le pont USB ADB.
echo.
echo Verification des peripheriques ADB connectes...
"%~dp0..\bin\adb.exe" devices
echo.

set /p CHOIX_ETAPE="Voulez-vous (1) Copier les fichiers ROM/Root, ou (2) Verifier directement l'architecture/Root ? [1/2] : "
if "%CHOIX_ETAPE%"=="2" goto VERIFICATION_SYSTEME

:COPIE_FICHIERS
echo.
echo =====================================================================
echo    ETAPE B : TRANSFERT DES FICHIERS VERS LE RECOVERY (/sdcard/)
echo =====================================================================
echo.

rem Recherche de paquets ROM dans roms\
set ROM_COUNT=0
for %%f in ("%~dp0roms\*.zip") do (
    set /a ROM_COUNT+=1
    echo [*] Copie de la ROM detectee : "%%~nxf" ...
    "%~dp0..\bin\adb.exe" push "%%f" /sdcard/
)

if %ROM_COUNT% equ 0 (
    echo [!] Aucune archive ROM .zip detectee dans .\roms\.
    echo     Consultez .\roms\README_ROMS.md pour telecharger crDroid 9 ou LineageOS 20.
    echo     Vous pouvez copier l'archive .zip de votre choix dans .\roms\ a tout moment.
)

rem Copie du paquet Magisk pour le root
if exist "%~dp0roms\Magisk-v26.4.apk" (
    echo [*] Copie de Magisk v26.4 vers /sdcard/Magisk-v26.4.zip ...
    "%~dp0..\bin\adb.exe" push "%~dp0roms\Magisk-v26.4.apk" /sdcard/Magisk-v26.4.zip
    if %errorlevel% equ 0 (
        echo [+] Magisk v26.4 copie avec succes sous /sdcard/Magisk-v26.4.zip !
    ) else (
        echo [-] Echec du transfert de Magisk via ADB.
    )
)

echo.
echo =====================================================================
echo    INSTRUCTIONS DANS LE RECOVERY DU REDMI 10A :
echo =====================================================================
echo  1. Formatage initial (OBLIGATOIRE si transition depuis stock MIUI) :
echo     - Allez dans 'Wipe' ^> 'Format Data'
echo     - Tapez 'yes' et validez (supprime le chiffrement materiel)
echo.
echo  2. Installation de la Custom ROM :
echo     - Allez dans 'Install' ^> selectionnez le fichier .zip de la ROM
echo     - Glissez pour confirmer le flash
echo.
echo  3. Installation du Root 64-bit :
echo     - Allez dans 'Install' ^> selectionnez '/sdcard/Magisk-v26.4.zip'
echo     - Glissez pour confirmer le flash
echo.
echo  4. Redemarrage :
echo     - Cliquez sur 'Reboot System'
echo     - Laissez le telephone demarrer (premier boot : 2 a 3 minutes)
echo =====================================================================
echo.

set /p LANCER_VERIF="Une fois le telephone demarre sur Android avec debogage USB active, passer aux verifications ? (O/N) : "
if /i not "%LANCER_VERIF%"=="O" goto FIN

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
    echo [+] VALIDATION CONFORME : Le systeme tourne bien en 64-bit natif (arm64-v8a) !
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
    echo [+] VALIDATION CONFORME : Privileges root obtenus avec succes (uid=0) !
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
