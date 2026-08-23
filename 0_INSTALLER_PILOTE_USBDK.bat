@echo off
chcp 65001 >nul
title 0. INSTALLATEUR PILOTE USBDK (MODE ADMINISTRATEUR)
echo =====================================================================
echo    ETAPE 0 : INSTALLATION DU PILOTE OFFICIEL USBDK (RED HAT / DAYNIX)
echo =====================================================================
echo.
echo Ce pilote permet a Windows de communiquer directement avec le processeur
echo MediaTek MT6785 lorsque le telephone est eteint (Mode BootROM).
echo.
echo Verification des droits Administrateur...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Elevation des privileges Administrateur en cours (UAC)...
    powershell -Command "Start-Process msiexec.exe -ArgumentList '/i', '\"%~dp0drivers\UsbDk_1.0.22_x64.msi\"' -Verb RunAs -Wait"
) else (
    msiexec /i "%~dp0drivers\UsbDk_1.0.22_x64.msi"
)
echo.
echo =====================================================================
echo    INSTALLATION DU PILOTE TERMINEE !
echo =====================================================================
pause
