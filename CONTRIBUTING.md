# Contribuer au Begonia Fleet Tool

## Prerequis Materiels

> Toute modification de la logique de flash (src/flash_stock_complete.py, begonia_tool.ps1) **doit etre testee sur un Xiaomi Redmi Note 8 Pro (MT6785) physique** avant soumission.

## Environnement de Developpement

```bash
git clone https://github.com/Arhkos/Begonia-Fleet-Tool.git
cd Begonia-Fleet-Tool
pip install -r requirements.txt

# Option : utiliser la version upstream de mtkclient
git submodule add https://github.com/bkerler/mtkclient.git src/mtkclient
```

## Style de Code

- **PowerShell** : respecter PSScriptAnalyzer, verifier `$LASTEXITCODE` apres chaque commande critique
- **Python** : formater avec Ruff (`ruff check src/`)
- **BAT** : toujours utiliser `%~dp0` pour les chemins relatifs

## Workflow Pull Request

1. Branche descriptive : `fix/lastexitcode-checks` ou `feat/sha256-verification`
2. Commits au format Conventional Commits
3. Si la PR modifie le flash : joindre les logs complets d'une session reelle
4. PR vers la branche `main`
