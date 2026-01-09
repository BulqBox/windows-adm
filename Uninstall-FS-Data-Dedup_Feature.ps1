<#
.SYNOPSIS
    Désinstallation de la fonctionnalité Data Deduplication sur Windows Server
.DESCRIPTION
    Script de désinstallation pour déploiement SCCM avec logging détaillé et vérifications
.NOTES
    Exit Codes:
    0 = Succès (désinstallation effectuée)
    1 = Fonctionnalité non installée (rien à faire)
    2 = Erreur lors de la désinstallation
    3 = Déduplication active sur des volumes (blocage sécurité)
    3010 = Succès mais redémarrage requis
#>

# Configuration
$LogPath = "C:\Temp\OSF-Script-Logs"
$LogFile = Join-Path $LogPath "Dedup-Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$FeatureName = "FS-Data-Deduplication"

# Création du dossier de log si nécessaire
if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    Write-Host $LogMessage
}

# Début du script
Write-Log "========================================"
Write-Log "Début de la désinstallation de Data Deduplication"
Write-Log "Serveur: $env:COMPUTERNAME"

try {
    # Vérification si la fonctionnalité est installée
    Write-Log "Vérification de l'état de la fonctionnalité $FeatureName"
    $Feature = Get-WindowsFeature -Name $FeatureName
    
    if ($Feature.Installed -eq $false) {
        Write-Log "La fonctionnalité $FeatureName n'est pas installée" "INFO"
        Write-Log "Aucune action nécessaire"
        Write-Log "========================================"
        exit 1
    }
    
    Write-Log "Fonctionnalité installée - Vérification des volumes"
    
    # Vérification des volumes avec déduplication active
    try {
        $DedupVolumes = Get-DedupVolume -ErrorAction Stop | Where-Object { $_.Enabled -eq $true }
        
        if ($DedupVolumes) {
            Write-Log "ALERTE: Déduplication active sur un ou plusieurs volumes !" "ERROR"
            Write-Log "Nombre de volumes concernés: $($DedupVolumes.Count)" "ERROR"
            
            foreach ($Vol in $DedupVolumes) {
                Write-Log "  - Volume: $($Vol.Volume) | Savings: $($Vol.SavingsRate)% | Enabled: $($Vol.Enabled)" "ERROR"
            }
            
            # Vérification des jobs en cours
            $RunningJobs = Get-DedupJob -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Running" }
            if ($RunningJobs) {
                Write-Log "Jobs de déduplication en cours: $($RunningJobs.Count)" "WARNING"
                foreach ($Job in $RunningJobs) {
                    Write-Log "  - Job: $($Job.Type) sur $($Job.Volume) - Progression: $($Job.Progress)%" "WARNING"
                }
            }
            
            Write-Log "Désinstallation BLOQUÉE pour éviter la perte de données" "ERROR"
            Write-Log "Action requise: Désactiver la déduplication sur tous les volumes avant de relancer" "ERROR"
            Write-Log "Commande: Disable-DedupVolume -Volume <Lettre>" "INFO"
            Write-Log "========================================"
            exit 3
        }
        
        Write-Log "Aucun volume avec déduplication active détecté" "SUCCESS"
        
    }
    catch {
        # Si les cmdlets de dédup ne sont pas disponibles, on considère que c'est OK
        Write-Log "Impossible de vérifier les volumes (cmdlets indisponibles) - Poursuite" "WARNING"
    }
    
    Write-Log "Début de la désinstallation"
    
    # Désinstallation avec suppression complète des binaires
    $Result = Uninstall-WindowsFeature -Name $FeatureName -Remove -ErrorAction Stop
    
    # Analyse du résultat
    if ($Result.Success) {
        Write-Log "Désinstallation réussie" "SUCCESS"
        Write-Log "Redémarrage requis: $($Result.RestartNeeded)"
        
        if ($Result.RestartNeeded -eq "Yes") {
            Write-Log "ATTENTION: Un redémarrage est nécessaire" "WARNING"
            Write-Log "========================================"
            exit 3010  # Code SCCM pour redémarrage requis
        }
        
        Write-Log "========================================"
        exit 0
    }
    else {
        Write-Log "Échec de la désinstallation" "ERROR"
        Write-Log "ExitCode: $($Result.ExitCode)" "ERROR"
        Write-Log "========================================"
        exit 2
    }
}
catch {
    Write-Log "ERREUR CRITIQUE: $($_.Exception.Message)" "ERROR"
    Write-Log "Ligne d'erreur: $($_.InvocationInfo.ScriptLineNumber)" "ERROR"
    Write-Log "========================================"
    exit 2
}