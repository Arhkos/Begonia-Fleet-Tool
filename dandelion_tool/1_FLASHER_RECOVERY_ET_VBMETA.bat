@echo off
chcp 65001 >nul
title 1. FLASH RECOVERY ET VBMETA - FASTBOOT (REDMI 10A DANDELION)

echo =====================================================================
echo    REDMI 10A (DANDELION/BLOSSOM) - FLASH RECOVERY CUSTOM ^& VBMETA
echo    Desactivation AVB 2.0 (dm-verity) ^| Deploiement Custom Recovery
echo =====================================================================
echo.

echo INSTRUCTIONS POUR ENTRER EN MODE FASTBOOT :
echo  1. Eteignez completement le telephone (POWER maintenu 10 secondes).
echo  2. Maintenez enfonce [VOLUME BAS] + [POWER] simultanement.
echo  3. Relachez des que l'ecran affiche le logo FASTBOOT (ou lapin/texte orange).
echo  4. Branchez le cable USB reliant le telephone au PC.
echo.

echo Verification de la detection du peripherique Fastboot...
set "FB_DEV="
for /f "tokens=*" %%d in ('"%~dp0..\bin\fastboot.exe" devices 2^>nul') do (
    set "FB_DEV=%%d"
)

if not defined FB_DEV (
    echo.
    echo =====================================================================
    echo [-] ERREUR : Aucun peripherique Fastboot detecte !
    echo.
    echo Instructions de depannage :
    echo  1. Assurez-vous que le telephone est allume en mode FASTBOOT :
    echo     Eteindre completement, puis maintenir [VOLUME BAS] + [POWER].
    echo  2. Branchez le cable USB directement sur un port USB a l'arriere du PC.
    echo  3. Verifiez les pilotes 'Android Bootloader Interface' dans Windows.
    echo =====================================================================
    echo.
    pause
    exit /b 1
)

echo [+] Peripherique Fastboot detecte : %FB_DEV%
echo.

rem Verification de securite du modele (dandelion / blossom)
set "FB_PRODUCT="
for /f "tokens=2 delims=: " %%p in ('"%~dp0..\bin\fastboot.exe" getvar product 2^>^&1') do (
    if not defined FB_PRODUCT set "FB_PRODUCT=%%p"
)
if defined FB_PRODUCT (
    echo     Modele detecte : %FB_PRODUCT%
    if /i not "%FB_PRODUCT%"=="dandelion" if /i not "%FB_PRODUCT%"=="blossom" (
        echo [!] AVERTISSEMENT : Le peripherique detecte [%FB_PRODUCT%] ne correspond pas a dandelion/blossom !
        echo     Flash annule pour proteger l'appareil contre un mauvais micrologiciel.
        echo.
        pause
        exit /b 2
    )
)
echo.

echo Appuyez sur une touche pour lancer le flash de VBMeta et du Recovery...
pause >nul
echo.

echo [*] Etape 1/3 : Desactivation de la verification AVB 2.0 - VBMeta...
"%~dp0..\bin\fastboot.exe" --disable-verity --disable-verification flash vbmeta "%~dp0recovery\vbmeta.img"
if %errorlevel% neq 0 (
    echo.
    echo [-] ERREUR lors du flash de vbmeta.img - code %errorlevel%.
    echo     Verifiez que le bootloader est deverrouille et que le telephone est en mode Fastboot.
    pause
    exit /b %errorlevel%
)
if exist "%~dp0recovery\vbmeta_system.img" (
    echo [*] Flash de vbmeta_system...
    "%~dp0..\bin\fastboot.exe" flash vbmeta_system "%~dp0recovery\vbmeta_system.img"
)
if exist "%~dp0recovery\vbmeta_vendor.img" (
    echo [*] Flash de vbmeta_vendor...
    "%~dp0..\bin\fastboot.exe" flash vbmeta_vendor "%~dp0recovery\vbmeta_vendor.img"
)
echo [+] VBMeta et partitions AVB flashees avec succes !
echo.

if exist "%~dp0recovery\boot.img" (
    echo [*] Etape 2/3 : Flash du noyau certifie - boot.img et dtbo.img...
    "%~dp0..\bin\fastboot.exe" flash boot "%~dp0recovery\boot.img"
)
if exist "%~dp0recovery\dtbo.img" (
    "%~dp0..\bin\fastboot.exe" flash dtbo "%~dp0recovery\dtbo.img"
    echo [+] Noyau et DTBO synchronises avec succes !
    echo.
)

echo [*] Etape 3/3 : Flash du Custom Recovery - recovery.img...
"%~dp0..\bin\fastboot.exe" flash recovery "%~dp0recovery\recovery.img"
if %errorlevel% neq 0 (
    echo.
    echo [-] ERREUR lors du flash de recovery.img - code %errorlevel%.
    pause
    exit /b %errorlevel%
)
echo [+] Custom Recovery flashe avec succes !
echo.

echo [*] Redemarrage immediat vers le Custom Recovery...
echo [!] NOTE IMPORTANTE : Pour empecher le script stock 'install-recovery.sh'
echo     de restaurer le recovery MIUI d'origine, le telephone doit demarrer
echo     directement dans le Custom Recovery. Maintenez [VOLUME HAUT] si necessaire.
"%~dp0..\bin\fastboot.exe" reboot recovery

if %errorlevel% neq 0 (
    echo [!] Avertissement : Le redemarrage automatique a retourne le code %errorlevel%.
    echo     Maintenez manuellement [VOLUME HAUT] + [POWER] pour acceder au Recovery.
) else (
    echo [+] Redemarrage vers le Custom Recovery initie !
)

echo.
echo =====================================================================
echo    OPERATION TERMINEE AVEC SUCCES !
echo    Le telephone demarre dans le Custom Recovery.
echo =====================================================================
pause
