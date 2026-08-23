@echo off
chcp 65001 >nul
title 1. DEVERROUILLAGE BOOTLOADER ET BYPASS FRP - REDMI NOTE 8 PRO
echo =====================================================================
echo    ETAPE 1 : DEVERROUILLAGE DU BOOTLOADER + EFFACEMENT FRP (1 CLIC)
echo =====================================================================
echo.
echo INSTRUCTIONS POUR LE TELEPHONE :
echo 1. Debranchez le telephone du PC.
echo 2. Maintenez le bouton POWER pendant 10-15 secondes jusqu'a extinction COMPLETE (ecran noir).
echo 3. Maintenez enfonce [VOLUME HAUT] + [VOLUME BAS] en meme temps.
echo 4. Branchez le cable USB-C relie au PC tout en maintenant les boutons.
echo 5. Des que le texte commence a defiler a l'ecran, RELACHEZ les deux boutons !
echo.
echo Lancement de la sequence BROM (Deverrouillage + Wipe FRP)...
python "%~dp0src\mtkclient\mtk.py" multi "da seccfg unlock;e frp;e metadata,userdata,md_udc;reset"
echo.
echo =====================================================================
echo    OPERATION TERMINEE ! Le telephone est deverrouille et FRP efface.
echo =====================================================================
pause
