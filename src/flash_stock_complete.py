#!/usr/bin/env python3
"""
Flash Stock Complet (Standardisation & Débriquage Intégral 32 Partitions) pour Redmi Note 8 Pro (Begonia)
Flashing 100% de la ROM Stock Officielle MIUI 12.5.15.0 EEA en mode BootROM (Zero SP Flash Tool).
"""

import os
import sys

# Chemins relatifs aux dossiers du projet
src_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(src_dir)
mtkclient_dir = os.path.join(src_dir, "mtkclient")

if mtkclient_dir not in sys.path:
    sys.path.insert(0, mtkclient_dir)

STOCK_IMAGES_DIR = os.path.join(project_root, "stock_firmware", "images")

# Liste exacte des 32 partitions officielles selon flash_all.bat de Xiaomi
PARTITIONS_ORDER = [
    ("preloader", "preloader_begonia.bin"),
    ("lk", "lk.img"),
    ("lk2", "lk.img"),
    ("tee1", "tee.img"),
    ("tee2", "tee.img"),
    ("sspm_1", "sspm.img"),
    ("sspm_2", "sspm.img"),
    ("gz1", "gz.img"),
    ("gz2", "gz.img"),
    ("scp1", "scp.img"),
    ("scp2", "scp.img"),
    ("logo", "logo.bin"),
    ("dtbo", "dtbo.img"),
    ("spmfw", "spmfw.img"),
    ("exaid", "exaid.img"),
    ("oem_misc1", "oem_misc1.img"),
    ("md1img", "md1img.img"),
    ("cam_vpu1", "cam_vpu1.img"),
    ("cam_vpu2", "cam_vpu2.img"),
    ("cam_vpu3", "cam_vpu3.img"),
    ("audio_dsp", "audio_dsp.img"),
    ("vendor", "vendor.img"),
    ("system", "system.img"),
    ("cust", "cust.img"),
    ("cache", "cache.img"),
    ("userdata", "userdata.img"),
    ("recovery", "recovery.img"),
    ("vbmeta", "vbmeta.img"),
    ("boot", "boot.img"),
]

def main():
    print("=" * 70)
    print("  FLASH INTEGRAL ROM STOCK EUROPE (MIUI 12.5.15 EEA) - REDMI NOTE 8 PRO")
    print("  29 partitions : Preloader, LK1/2, TEE1/2, GZ1/2, SSPM1/2, SCP1/2, System, Vendor, Data")
    print("=" * 70)
    print()

    if not os.path.exists(STOCK_IMAGES_DIR):
        print(f"[-] ERREUR: Répertoire des images introuvable : {STOCK_IMAGES_DIR}")
        sys.exit(1)

    multi_cmds = []
    
    # 1. Nettoyage préventif
    multi_cmds.append("e metadata")
    multi_cmds.append("e expdb")
    
    # 2. Flash des 29 partitions officielles
    for part_name, filename in PARTITIONS_ORDER:
        file_path = os.path.join(STOCK_IMAGES_DIR, filename)
        if not os.path.exists(file_path):
            print(f"[-] ERREUR CRITIQUE : fichier '{filename}' manquant pour la partition '{part_name}'.")
            print("[-] Abandon du flash pour éviter un brick irréversible.")
            sys.exit(1)
        multi_cmds.append(f"w {part_name} {file_path}")

    # 3. Reset final
    multi_cmds.append("reset")

    joined_cmd = ";".join(multi_cmds)
    
    mtk_main_script = os.path.join(mtkclient_dir, "mtk.py")

    print(f"[*] Lancement de mtkclient ({len([c for c in multi_cmds if c.startswith('w ')])} partitions à flasher)...")
    import subprocess
    cmd = [sys.executable, mtk_main_script, "multi", joined_cmd]
    try:
        result = subprocess.run(cmd, check=True)
        return result.returncode
    except subprocess.CalledProcessError as e:
        print(f"[-] Erreur fatale : mtkclient a retourné le code d'erreur {e.returncode}.")
        sys.exit(e.returncode)

if __name__ == "__main__":
    sys.exit(main() or 0)
