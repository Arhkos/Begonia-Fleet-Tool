@echo off
chcp 65001 >nul
title FLASH RECOVERY CRDROID OFFICIEL - REDMI 10A

echo =====================================================================
echo    REDMI 10A - FLASH DU RECOVERY ^& KERNEL OFFICIELS CRDROID
echo =====================================================================
echo.

echo [*] Verification de la presence du peripherique Fastboot...
"%~dp0..\bin\fastboot.exe" devices
echo.

echo [*] Flash de vbmeta (verification desactivee)...
"%~dp0..\bin\fastboot.exe" flash vbmeta "%~dp0recovery\crdroid\vbmeta.img"
"%~dp0..\bin\fastboot.exe" flash vbmeta_system "%~dp0recovery\crdroid\vbmeta_system.img"
"%~dp0..\bin\fastboot.exe" flash vbmeta_vendor "%~dp0recovery\crdroid\vbmeta_vendor.img"

echo [*] Flash du kernel et des arbres de peripheriques (boot ^& dtbo)...
"%~dp0..\bin\fastboot.exe" flash boot "%~dp0recovery\crdroid\boot.img"
"%~dp0..\bin\fastboot.exe" flash dtbo "%~dp0recovery\crdroid\dtbo.img"

echo [*] Flash du Custom Recovery crDroid...
"%~dp0..\bin\fastboot.exe" flash recovery "%~dp0recovery\crdroid\recovery.img"

echo.
echo =====================================================================
echo [+] FLASH COMPLET TERMINE AVEC SUCCES !
echo [*] Redemarrage vers le Recovery crDroid...
echo =====================================================================
"%~dp0..\bin\fastboot.exe" reboot recovery
pause
