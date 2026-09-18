<#
.SYNOPSIS
    Met à jour une liste d'applications via WinGet.

.DESCRIPTION
    Ce script vérifie la disponibilité de WinGet puis tente de mettre à jour
    automatiquement une liste définie d'applications à partir de leurs identifiants WinGet.

    Les mises à jour sont exécutées silencieusement et sans interaction utilisateur.

    Une fenêtre de mise à jour peut être activée afin de limiter l'exécution
    à certains jours du mois.

.PARAMETER PackageIdsToUpgrade
    Liste des identifiants WinGet à mettre à jour.

.PARAMETER StartDay
    Premier jour autorisé du mois.

.PARAMETER EndDay
    Dernier jour autorisé du mois.

.PARAMETER LogDir
    Répertoire contenant le journal d'exécution.
    Par défaut :
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs

.PARAMETER LogFileName
    Nom du fichier journal.

.NOTES
    Auteur                : Matthieu Dasnoy
    Date de création      : 03/09/2026
    Dernière modification : 03/09/2026
    Version               : 1.0

    Le script doit être exécuté avec des privilèges administrateur.
    Dans Microsoft Intune, utiliser le contexte système.

    Historique des versions :

    1.0 - 03/09/2026
    - Version initiale.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string[]]$PackageIdsToUpgrade = @(     # Modifier la liste des packages IDs à mettre à jour ici
        '7zip.7zip',
        'Adobe.Acrobat.Reader.64-bit',
        'Lenovo.SystemUpdate'
    ),

    [ValidateRange(1, 31)]
    [int]$StartDay = 1,                     # Modifier le début de la fenêtre d'installation ici

    [ValidateRange(1, 31)]
    [int]$EndDay = 31,                      # Modifier la fin de la fenêtre d'installation ici

    [ValidateNotNullOrEmpty()]
    [string]$LogDir = (Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs'),

    [ValidateNotNullOrEmpty()]
    [string]$LogFileName = 'winget_auto_upgrade.log'
)

function Get-WinGetExecutable {
    $AppxParameters = @{
        AllUsers    = $true
        Name        = 'Microsoft.DesktopAppInstaller'
        ErrorAction = 'Stop'
    }

    $WinGetPackage = Get-AppxPackage @AppxParameters |
        Sort-Object { [version]$_.Version } |
        Select-Object -Last 1

    if (-not $WinGetPackage.InstallLocation) {
        throw 'Package Microsoft.DesktopAppInstaller introuvable.'
    }

    $WinGetExecutable = Join-Path $WinGetPackage.InstallLocation 'winget.exe'

    if (-not (Test-Path $WinGetExecutable -PathType Leaf)) {
        throw "Exécutable WinGet introuvable : $WinGetExecutable"
    }

    & $WinGetExecutable --version | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "WinGet non exécutable, code : $LASTEXITCODE"
    }

    return $WinGetExecutable
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$ExitCode = 1

$TranscriptStarted = $false

try {
    if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }

    $LogPath = Join-Path $LogDir $LogFileName
    Start-Transcript -Path $LogPath -Append -Force
    $TranscriptStarted = $true

} catch {
    Write-Output "[$(Get-Date -Format s)] Journalisation impossible : $($_.Exception.Message)"
}

try {
    $RunUpgrade = $true

    # Fenêtre de mise à jour autorisée
    if ($StartDay -gt $EndDay) {
        throw 'StartDay ne peut pas être supérieur à EndDay.'
    }

    $DayOfMonth = (Get-Date).Day

    if ($DayOfMonth -lt $StartDay -or $DayOfMonth -gt $EndDay) {
        Write-Output "[$(Get-Date -Format s)] Hors fenêtre de mise à jour."
        $RunUpgrade = $false
        $ExitCode = 0
    }

    # Mises à jour
    if ($RunUpgrade) {
        $WinGetExe = Get-WinGetExecutable
        Write-Output "[$(Get-Date -Format s)] WinGet opérationnel"

        $GlobalSuccess = $true

        foreach ($PackageId in $PackageIdsToUpgrade) {

            Write-Output "[$(Get-Date -Format s)] Vérification de la mise à jour : $PackageId"

            $WinGetArgs = @(
                'upgrade',
                '--id', $PackageId,
                '--exact',
                '--silent',
                '--accept-source-agreements',
                '--accept-package-agreements',
                '--disable-interactivity',
                '--scope', 'machine'
            )

            Write-Output "[$(Get-Date -Format s)] Exécution de la commande : $WinGetExe $($WinGetArgs -join ' ')"

            & $WinGetExe $WinGetArgs

            $AppExitCode = $LASTEXITCODE

            switch ($AppExitCode) {
                0 {
                    Write-Output "[$(Get-Date -Format s)] Mise à jour de $PackageId terminée avec succès"
                }

                -1978335189 {
                    Write-Output "[$(Get-Date -Format s)] Aucune mise à jour applicable pour $PackageId"
                }

                default {
                    Write-Output "[$(Get-Date -Format s)] WinGet upgrade $PackageId a échoué (exit code: $AppExitCode)"
                    $GlobalSuccess = $false
                }
            }
        }

        Write-Output

        if ($GlobalSuccess) {
            Write-Output "[$(Get-Date -Format s)] Traitement WinGet terminé avec succès"
            $ExitCode = 0
        } else {
            Write-Output "[$(Get-Date -Format s)] Traitement WinGet terminé avec une ou plusieurs erreurs"
            $ExitCode = 1
        }
    }

} catch {
    Write-Output "[$(Get-Date -Format s)] Erreur : $($_.Exception.Message)"
    $ExitCode = 1

} finally {
    if ($TranscriptStarted) {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }
}

exit $ExitCode

