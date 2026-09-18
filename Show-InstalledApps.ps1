<#
.SYNOPSIS
    Affiche les applications installées enregistrées dans le Registre.

.DESCRIPTION
    Ce script recherche les applications installées dans les emplacements
    de désinstallation 64 bits et 32 bits du Registre.

    Pour chaque application, il affiche l'identifiant de la clé de Registre,
    le nom affiché et la version installée.

.EXAMPLE
    .\Show-InstalledApps.ps1

    Affiche toutes les applications trouvées.

.NOTES
    Auteur                : Matthieu Dasnoy
    Date de création      : 03/09/2026
    Dernière modification : 03/09/2026
    Version               : 1.0

    Historique des versions :

    1.0 - 03/09/2026
    - Version initiale.
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'

$RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

try {
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        throw 'Ce script doit être exécuté avec PowerShell 64 bits.'
    }

    $Applications = Get-ItemProperty -Path $RegistryPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        ForEach-Object {
            [PSCustomObject]@{
                Id          = $_.PSChildName
                DisplayName = $_.DisplayName
                Version     = $_.DisplayVersion
            }
        } |
        Sort-Object DisplayName, Version, Id

    if (-not $Applications) {
        Write-Host 'Aucune application trouvée.'
    }

    $Applications | Format-Table -AutoSize
    
} catch {
    Write-Error "Erreur lors de la lecture des applications : $($_.Exception.Message)"
}
