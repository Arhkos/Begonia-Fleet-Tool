@echo off
chcp 65001 >nul
title 2. STANDARDISATION & UNBRICK STOCK MIUI 12.5 EEA - REDMI NOTE 8 PRO
echo =====================================================================
echo    ETAPE 2 : FLASH INTEGRAL DE LA ROM STOCK D'USINE (32 PARTITIONS)
echo =====================================================================
echo.
echo Ce script reecrit 100%% des 32 partitions officielles d'usine Xiaomi :
echo - Bootloader & Securite : Preloader, LK1/2, TEE1/2, GZ1/2, SSPM1/2, SCP1/2
echo - Noyau & Radio : Boot, Recovery, DTBO, VBMeta, Logo, MD1IMG, Audio_DSP, Cam_VPU
echo - Systeme & OS : System (3.6 Go), Vendor (1.2 Go), Cust (700 Mo), Userdata (1.2 Go), Cache
echo.
echo ATTENTION : Ce processus ecrit 7 Go de donnees et dure environ 3 a 5 minutes.
echo NE DEBRANCHEZ SOUS AUCUN PRETEXTE LE CABLE USB PENDANT L'OPERATION !
echo.
echo INSTRUCTIONS POUR LE TELEPHONE :
echo 1. Eteignez le telephone (POWER 10-15s jusqu'a ecran noir).
echo 2. Maintenez enfonce [VOLUME HAUT] + [VOLUME BAS] en meme temps.
echo 3. Branchez le cable USB-C relie au PC tout en maintenant les boutons.
echo 4. Des que le flash commence a afficher les barres de progression, RELACHEZ les boutons.
echo.
echo Lancement du flash d'usine complet...
python "%~dp0src\flash_stock_complete.py"
echo.
echo =====================================================================
echo    FLASH STOCK TERMINE ! Le telephone est 100%% standardise et fonctionnel.
echo =====================================================================
pause
