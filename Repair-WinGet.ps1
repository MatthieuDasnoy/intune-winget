<#
.SYNOPSIS
    Installe ou répare WinGet.

.DESCRIPTION
    Ce script vérifie d'abord si WinGet est opérationnel. Si c'est le cas,
    aucune remédiation n'est effectuée.

    Dans le cas contraire, il installe le fournisseur NuGet et le module
    Microsoft.WinGet.Client, puis utilise Repair-WinGetPackageManager pour
    installer ou réparer WinGet.

    La remédiation est considérée comme réussie uniquement si winget.exe est présent
    et peut être exécuté après l'opération.

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
    [string]$LogDir = (Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs'),

    [ValidateNotNullOrEmpty()]
    [string]$LogFileName = 'winget_remediation.log'
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
    try {
        $WinGetExe = Get-WinGetExecutable

        Write-Output "[$(Get-Date -Format s)] WinGet est déjà opérationnel : $WinGetExe"
        Write-Output "[$(Get-Date -Format s)] Aucune remédiation nécessaire"
        $ExitCode = 0

    } catch {
        Write-Output "[$(Get-Date -Format s)] WinGet absent ou non opérationnel"
        Write-Output "[$(Get-Date -Format s)] Détail : $($_.Exception.Message)"
        Write-Output "[$(Get-Date -Format s)] Démarrage de la remédiation"

        Write-Output "[$(Get-Date -Format s)] Installation du fournisseur NuGet"
        Install-PackageProvider -Name NuGet -Force | Out-Null

        Write-Output "[$(Get-Date -Format s)] Installation du module Microsoft.WinGet.Client"
        $ModuleParameters = @{
            Name       = 'Microsoft.WinGet.Client'
            Scope      = 'AllUsers'
            Repository = 'PSGallery'
            Force      = $true
        }

        Install-Module @ModuleParameters | Out-Null

        Import-Module -Name Microsoft.WinGet.Client -Force

        Write-Output "[$(Get-Date -Format s)] Installation ou réparation de WinGet"
        Repair-WinGetPackageManager -AllUsers

        $WinGetExe = Get-WinGetExecutable

        Write-Output "[$(Get-Date -Format s)] WinGet opérationnel après remédiation : $WinGetExe"
        $ExitCode = 0
    }

} catch {
    Write-Output "[$(Get-Date -Format s)] Erreur lors de l'installation ou de la réparation de WinGet"
    Write-Output "[$(Get-Date -Format s)] Erreur : $($_.Exception.Message)"
    $ExitCode = 1

} finally {
    if ($TranscriptStarted) {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }
}

exit $ExitCode
