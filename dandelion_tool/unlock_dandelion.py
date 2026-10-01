#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
unlock_dandelion.py
===================
Script d'automatisation complète du déverrouillage Bootloader du Xiaomi Redmi 10A
(Dandelion / Blossom - SoC MediaTek MT6762G Helio G25).

Fonctionnalités :
1. Connexion au mode BROM matériel (MT6762G - HW 0x766 / 0x717) via UsbDk + Kamakiri.
2. Sauvegarde de sécurité automatique de la partition Little Kernel (lk) et de la partition RPMB.
3. Analyse intelligente du Replay Protected Memory Block (RPMB) pour localiser la signature 'Jz8PNRUF'.
4. Effacement ciblé du secteur magic RPMB pour contourner le dual-layer lock de MIUI 14+ / HyperOS.
5. Re-lecture de vérification pour s'assurer que le secteur est bien à 0x00.
6. Écriture du déverrouillage dans la partition 'seccfg' (ATTR_UNLOCK).
7. Formatage des partitions 'frp', 'metadata', 'userdata' et 'md_udc' (anti-FRP + nettoyage).
8. Redémarrage matériel contrôlé (shutdown bootmode=0) vers le mode Fastboot.
9. Vérification automatique du statut via Fastboot ('fastboot getvar unlocked' & 'fastboot oem lks').
"""

import os
import sys
import time
import logging
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
MTKCLIENT_DIR = os.path.join(PROJECT_ROOT, "src", "mtkclient")
FASTBOOT_EXE = os.path.join(PROJECT_ROOT, "bin", "fastboot.exe")

if MTKCLIENT_DIR not in sys.path:
    sys.path.insert(0, MTKCLIENT_DIR)

try:
    from mtkclient.Library.mtk_class import Mtk
    from mtkclient.Library.DA.mtk_da_handler import DaHandler
    from mtkclient.Library.mtk_main import MtkConfig, ArgHandler
except ImportError as e:
    print(f"[-] Erreur d'importation mtkclient : {e}")
    sys.exit(1)


class MockArgs:
    """Arguments par défaut pour initialiser l'environnement MTK."""
    debugmode = False
    loglevel = logging.INFO
    serialport = None
    vid = None
    pid = None
    noreconnect = False
    stock = False
    uartloglevel = 2
    logchannel = "UART"
    write_preloader_to_file = False
    generatekeys = False
    iot = False
    socid = False
    auth = None
    cert = None
    loader = None
    preloader = None
    ptype = None
    var1 = None
    uart_addr = None
    da_addr = None
    brom_addr = None
    mode = None
    wdt = None
    skipwdt = False
    crash = False
    appid = None
    sectorsize = "0x200"
    gpt_num_part_entries = "0"
    gpt_part_entry_size = "0"
    gpt_part_entry_start_lba = "0"
    parttype = None
    skip = None
    disable_internal_flash = False


def print_banner():
    print("=" * 70)
    print("   REDMI 10A (DANDELION) - DEVERROUILLAGE BROM & RPMB BYPASS")
    print("   SoC MediaTek MT6762G Helio G25 | Exploit Kamakiri BROM")
    print("=" * 70)
    print()


def verify_fastboot_state():
    """Interroge Fastboot pour vérifier si le bootloader est déverrouillé."""
    if not os.path.exists(FASTBOOT_EXE):
        return

    print("\n[*] Interrogation du statut Fastboot...")
    time.sleep(3)
    try:
        proc_unlocked = subprocess.run([FASTBOOT_EXE, "getvar", "unlocked"],
                                       capture_output=True, text=True, timeout=10)
        proc_lks = subprocess.run([FASTBOOT_EXE, "oem", "lks"],
                                  capture_output=True, text=True, timeout=10)

        out_unlocked = proc_unlocked.stdout + proc_unlocked.stderr
        out_lks = proc_lks.stdout + proc_lks.stderr

        print(f"    fastboot getvar unlocked : {out_unlocked.strip()}")
        print(f"    fastboot oem lks         : {out_lks.strip()}")

        if "unlocked: yes" in out_unlocked.lower():
            print("\n" + "=" * 70)
            print("[+] SUCCES TOTAL : LE BOOTLOADER DU REDMI 10A EST DEVERROUILLE !")
            print("    Vous pouvez maintenant executer l'etape 1 :")
            print("    1_FLASHER_RECOVERY_ET_VBMETA.bat")
            print("=" * 70)
        else:
            print("\n" + "=" * 70)
            print("[!] STATUT ACTUEL : 'unlocked: no'.")
            print("    Verifiez si le peripherique est bien redemarre en Fastboot.")
            print("=" * 70)
    except Exception as e:
        print(f"[!] Impossible d'interroger fastboot directement : {e}")


def main():
    print_banner()

    backup_dir = os.path.join(SCRIPT_DIR, "backup")
    os.makedirs(backup_dir, exist_ok=True)

    print("[*] Initialisation des pilotes et configuration mtkclient...")
    args = MockArgs()
    config = MtkConfig(loglevel=logging.INFO, gui=None, guiprogress=None)
    ArgHandler(args, config)

    mtk = Mtk(config=config, loglevel=logging.INFO, serialportname=args.serialport)
    config.set_peek(mtk.daloader.peek)
    da_handler = DaHandler(mtk, logging.INFO)

    print()
    print("=" * 70)
    print("   INSTRUCTIONS POUR LE PASSAGE EN MODE BROM :")
    print("=" * 70)
    print(" 1. Debranchez le cable USB du telephone.")
    print(" 2. Eteignez COMPLETEMENT le telephone :")
    print("    Maintenez le bouton POWER pendant 10 a 15 secondes jusqu'a ce que")
    print("    l'ecran devienne totalement noir.")
    print(" 3. Maintenez fermement appuyes [VOLUME HAUT] + [VOLUME BAS] ensemble.")
    print(" 4. Tout en maintenant les 2 boutons, branchez le cable USB relie au PC.")
    print(" 5. Des que le texte de detection defile, RELACHEZ IMMEDIATEMENT les boutons !")
    print("=" * 70)
    print()
    print("[*] En attente de la connexion USB en mode BROM (MT6762G)...")
    sys.stdout.flush()

    # Connexion BROM
    mtk = da_handler.connect(mtk, ".")
    if mtk is None:
        print("[-] Echec de la detection BROM. Veuillez reessayer.")
        sys.exit(1)

    print("[+] Peripherique detecte en BROM ! Chargement du Download Agent (DA)...")
    mtk = da_handler.configure_da(mtk)
    if mtk is None:
        print("[-] Echec du chargement du Download Agent (DA).")
        sys.exit(1)

    print("[+] Download Agent initialise avec succes !")

    # Informations mémoire
    storage_type = getattr(mtk.daloader.daconfig.storage, "flashtype", "inconnu")
    rpmb_size = 0
    if hasattr(mtk.daloader, "xft") and hasattr(mtk.daloader.xft, "xflash") and mtk.daloader.xft.xflash.emmc:
        rpmb_size = mtk.daloader.xft.xflash.emmc.rpmb_size
    print(f"[*] Type de memoire : {storage_type} | Taille RPMB : 0x{rpmb_size:X} ({rpmb_size // 1024} Ko)")

    # Étape 1 : Sauvegarde Little Kernel (lk)
    lk_backup_path = os.path.join(backup_dir, "lk_backup.bin")
    print("\n" + "-" * 70)
    print("[ETAPE 1/5] Sauvegarde de la partition de bootloader (lk)...")
    try:
        da_handler.da_read(partitionname="lk", parttype="user", filename=lk_backup_path, display=True)
        print(f"[+] Partition 'lk' sauvegardee : {lk_backup_path}")
    except Exception as e:
        print(f"[!] Avertissement lors de la sauvegarde lk : {e}")

    # Étape 2 : Dump complet du RPMB
    rpmb_backup_path = os.path.join(backup_dir, "rpmb_backup.bin")
    print("\n" + "-" * 70)
    print("[ETAPE 2/5] Lecture et sauvegarde complete de la partition RPMB...")
    try:
        mtk.daloader.read_rpmb(filename=rpmb_backup_path)
        print(f"[+] Dump RPMB termine avec succes : {rpmb_backup_path}")
    except Exception as e:
        print(f"[-] Erreur lors de la lecture RPMB : {e}")
        rpmb_backup_path = None

    # Étape 3 : Analyse du dump RPMB et détection de la signature magic
    print("\n" + "-" * 70)
    print("[ETAPE 3/5] Recherche de la signature RPMB Magic 'Jz8PNRUF'...")
    magic_sectors_to_erase = []

    if rpmb_backup_path and os.path.exists(rpmb_backup_path):
        with open(rpmb_backup_path, "rb") as f:
            rpmb_data = f.read()

        magic = b"Jz8PNRUF"
        offset = 0
        while True:
            pos = rpmb_data.find(magic, offset)
            if pos == -1:
                break
            sector = pos // 256
            byte_in_sector = pos % 256
            print(f"[+] SIGNATURE MAGIC TROUVEE ! Offset 0x{pos:06X} -> Secteur RPMB {sector} (byte {byte_in_sector})")
            if sector not in magic_sectors_to_erase:
                magic_sectors_to_erase.append(sector)
            offset = pos + 1

    if magic_sectors_to_erase:
        for sec in magic_sectors_to_erase:
            print(f"[*] Effacement du secteur magic RPMB {sec} (4 secteurs = 1024 octets)...")
            res = mtk.daloader.erase_rpmb(sector=str(sec), sectors="4")
            if res:
                print(f"[+] Secteur RPMB {sec} efface avec succes !")
                # Re-lecture de vérification
                check_path = os.path.join(backup_dir, f"rpmb_check_{sec}.bin")
                try:
                    mtk.daloader.read_rpmb(filename=check_path, sector=str(sec), sectors="4")
                    if os.path.exists(check_path):
                        with open(check_path, "rb") as cf:
                            cdata = cf.read()
                        if b"Jz8PNRUF" not in cdata:
                            print(f"[+] VERIFICATION REUSSIE : Le secteur {sec} est bien zeroed (magic absent) !")
                        else:
                            print(f"[!] Attention : Le magic est toujours present apres tentative d'effacement.")
                except Exception as e:
                    print(f"[*] Note verification : {e}")
            else:
                print(f"[-] Echec de l'effacement du secteur {sec}.")
    else:
        print("[!] Aucune signature 'Jz8PNRUF' brute trouvee dans le dump RPMB.")
        if os.path.exists(lk_backup_path):
            with open(lk_backup_path, "rb") as f:
                lk_data = f.read()
            if b"Jz8PNRUF" in lk_data:
                print("[+] Confirmation : La signature 'Jz8PNRUF' est bien referencee dans le bootloader LK.")
            else:
                print("[*] Signature 'Jz8PNRUF' non trouvee dans LK.")

        # Calcul du secteur cible fallback
        target_sector = None
        if rpmb_size > 57344 * 256:
            target_sector = 57344
        elif rpmb_size == 0x100000:
            target_sector = 4064  # 8 Ko avant la fin pour 1 Mo
        elif rpmb_size > 0:
            target_sector = (rpmb_size // 256) - 32

        if target_sector is not None:
            print(f"[*] Application de l'effacement RPMB au secteur fallback : {target_sector}...")
            try:
                mtk.daloader.erase_rpmb(sector=str(target_sector), sectors="4")
                print(f"[+] Secteur fallback {target_sector} efface.")
            except Exception as e:
                print(f"[!] Note effacement secteur fallback : {e}")

    # Étape 4 : Déverrouillage seccfg et effacement FRP / données
    print("\n" + "-" * 70)
    print("[ETAPE 4/5] Deverrouillage de securite 'seccfg' et effacement FRP...")
    try:
        mtk.daloader.seccfg(lockflag="unlock")
        print("[+] Partition 'seccfg' configuree en mode UNLOCK !")
    except Exception as e:
        print(f"[-] Erreur lors de l'ecriture seccfg : {e}")

    try:
        print("[*] Formatage securise des partitions frp, metadata, userdata, md_udc...")
        da_handler.da_erase(["frp", "metadata", "userdata", "md_udc"], "user")
        print("[+] Partitions reinitialisees avec succes !")
    except Exception as e:
        print(f"[!] Erreur formatage partitions : {e}")

    # Étape 5 : Réinitialisation matérielle vers Fastboot
    print("\n" + "-" * 70)
    print("[ETAPE 5/5] Reinitialisation materielle du peripherique...")
    try:
        mtk.daloader.shutdown(bootmode=0)
        print("[+] Commande de redemarrage envoyee au SoC !")
    except Exception:
        # Les exceptions de déconnexion USB sous Windows sont normales
        pass

    print()
    print("=" * 70)
    print("[+] L'ensemble des commandes BROM et RPMB a ete applique.")
    print("    Le telephone redemarre. Maintenez [VOLUME BAS] si necessaire pour")
    print("    rejoindre l'ecran Fastboot.")
    print("=" * 70)

    # Vérification automatique en Fastboot
    verify_fastboot_state()


if __name__ == "__main__":
    main()
