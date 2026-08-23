@echo off
chcp 65001 >nul
title 3. FLASH RECOVERY BRP 3.6 ^& VBMETA - FASTBOOT (REDMI NOTE 8 PRO)
echo =====================================================================
echo    ETAPE 3 : FLASH DU RECOVERY BRP 3.6 + VBMETA (MODE FASTBOOT)
echo =====================================================================
echo.
echo INSTRUCTIONS :
echo 1. Mettez le telephone en mode FASTBOOT (Maintenez VOLUME BAS + POWER enfonce).
echo 2. Branchez le cable USB au PC.
echo.
echo Flash des images de demarrage (Fastboot local autonome)...
"%~dp0bin\fastboot.exe" flash recovery "%~dp0recovery\BRPv3.6.img"
"%~dp0bin\fastboot.exe" flash recovery "%~dp0recovery\recovery.img"
"%~dp0bin\fastboot.exe" flash vbmeta "%~dp0recovery\vbmeta.img" --disable-verity --disable-verification
echo.
echo Redemarrage vers le Recovery BRP 3.1...
"%~dp0bin\fastboot.exe" reboot recovery
echo.
echo =====================================================================
echo    FLASH TERMINE !
echo    Si l'ecran reste noir, maintenez [VOLUME HAUT] pour afficher TWRP.
echo =====================================================================
pause
