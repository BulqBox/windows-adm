# windows-adm
Some scripts about Windows administration

## Uninstall-DataDeduplication

Script PowerShell pour désinstaller la fonctionnalité Data Deduplication sur Windows Server avec vérifications de sécurité.

### Description

Script robuste conçu pour les déploiements à grande échelle via SCCM/ConfigMgr. Il désinstalle complètement la fonctionnalité Data Deduplication tout en vérifiant qu'aucun volume n'utilise activement cette fonctionnalité avant de procéder.

### Fonctionnalités

- ✅ Vérification de l'état d'installation de la fonctionnalité
- ✅ Détection des volumes avec déduplication active (sécurité)
- ✅ Détection des jobs de déduplication en cours
- ✅ Suppression complète des binaires (`-Remove`)
- ✅ Logging détaillé avec horodatage
- ✅ Exit codes standardisés pour SCCM
- ✅ Gestion du redémarrage requis

### Prérequis

- Windows Server 2012 R2 ou ultérieur
- Droits administrateur
- Dossier `C:\Temp\Script` (créé automatiquement si inexistant)

### Utilisation

#### Exécution manuelle
```powershell
.\Uninstall-DataDeduplication.ps1
```

#### Déploiement SCCM
**Ligne de commande du programme :**
```
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Uninstall-DataDeduplication.ps1"
```

**Configuration recommandée :**
- Codes de retour de succès : `0`, `1`, `3010`
- Comportement de redémarrage : Autoriser si 3010
- Exécuter en tant que : SYSTEM

### Exit Codes

| Code | Signification | Action SCCM |
|------|---------------|-------------|
| `0` | Désinstallation réussie | Succès |
| `1` | Fonctionnalité non installée | Succès (rien à faire) |
| `2` | Erreur lors de la désinstallation | Échec |
| `3` | Déduplication active sur des volumes | Échec (blocage sécurité) |
| `3010` | Succès avec redémarrage requis | Succès + Reboot |

### Logs

Les logs sont générés dans `C:\Temp\Script\` avec le format :
```
Dedup-Uninstall_AAAAMMJJ_HHMMSS.log
```

**Exemple de log :**
```
[2025-01-09 14:32:15] [INFO] Début de la désinstallation de Data Deduplication
[2025-01-09 14:32:15] [INFO] Serveur: SRV-WEB01
[2025-01-09 14:32:16] [SUCCESS] Aucun volume avec déduplication active détecté
[2025-01-09 14:32:18] [SUCCESS] Désinstallation réussie
```

### Sécurité

Le script **bloque automatiquement** la désinstallation si :
- Un ou plusieurs volumes ont la déduplication activée
- Des jobs de déduplication sont en cours d'exécution

Pour forcer la désinstallation, désactiver d'abord la dédup sur les volumes concernés :
```powershell
Disable-DedupVolume -Volume D:
```
