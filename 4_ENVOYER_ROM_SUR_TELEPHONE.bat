@echo off
chcp 65001 >nul
title 4. ENVOI DES FICHIERS ROM PAR ADB - REDMI NOTE 8 PRO
echo =====================================================================
echo    ETAPE 4 : COPIE AUTOMATIQUE DU FIRMWARE R-OSS + PIXELEXPERIENCE 13
echo =====================================================================
echo.
echo =====================================================================
echo   ASTUCE INDISPENSABLE DANS TWRP POUR LA DETECTION USB :
echo   1. Sur l'ecran du telephone dans TWRP : Allez dans 'Mount'.
echo   2. Cliquez sur 'Disable MTP' puis recliquez sur 'Enable MTP'.
echo   (Cela initialise le pilote ADB sur votre PC Windows).
echo =====================================================================
echo.
echo Verification du peripherique ADB connecte...
"%~dp0bin\adb.exe" devices
echo.
echo [*] Transfert 1/2 : Copie du Firmware R-OSS + BRP 3.1...
"%~dp0bin\adb.exe" push "%~dp0roms\FW R-OSS + BRP 3.1 - Begonia.zip" /sdcard/
echo.
echo [*] Transfert 2/2 : Copie de la ROM PixelExperience Plus 13 (1.6 Go)...
"%~dp0bin\adb.exe" push "%~dp0roms\PixelExperience_Plus_begonia-13.0-20231217-1732-OFFICIAL.zip" /sdcard/
echo.
echo =====================================================================
echo    TRANSFERT REUSSI ! DERNIERES ETAPES DANS TWRP :
echo =====================================================================
echo  1. Install  : Flasher 'FW R-OSS + BRP 3.1 - Begonia.zip'
echo  2. Install  : Flasher 'PixelExperience_Plus_begonia-13.0...zip'
echo  3. Mount    : Cocher [System] et [Vendor]
echo  4. Advanced : Cliquer sur 'Root (Magisk)'
echo  5. Advanced : Cliquer sur 'Disable Force Encrypt'
echo  6. Advanced : Cliquer sur 'Disable TWRP Replace'
echo  7. Wipe     : Cliquer sur 'Format Data' et taper 'yes'
echo  8. Reboot   : System (Le telephone s'allume sous PixelExperience 13 !)
echo =====================================================================
pause
