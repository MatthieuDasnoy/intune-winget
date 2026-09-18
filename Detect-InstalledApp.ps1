<#
.SYNOPSIS
    Détecte une application installée à partir de son nom usuel.

.DESCRIPTION
    Ce script recherche une application dans les branches 64 et 32 bits de HKLM
    à partir de la propriété DisplayName de sa clé de désinstallation.

    La recherche est insensible à la casse et accepte une partie du nom affiché.
    Le script vérifie ensuite que la version installée est supérieure ou égale
    à la version cible.

    Le nom de l'application et la version cible sont définis par les valeurs
    par défaut des paramètres du script.

    Codes de retour :
    - 0 : l'application est installée dans une version suffisante ;
    - 1 : l'application est absente, sa version est invalide ou une mise à jour est requise.

.EXAMPLE
    .\Detect-InstalledApp.ps1

    Recherche l'application configurée et vérifie sa version.

.PARAMETER DisplayNameLike
    Texte recherché dans la propriété DisplayName.
    La recherche est partielle et insensible à la casse.

.PARAMETER TargetVersion
    Version minimale attendue.

.NOTES
    Auteur                : Matthieu Dasnoy
    Date de création      : 03/09/2026
    Dernière modification : 03/09/2026
    Version               : 1.0

    Le script est prévu pour une détection Microsoft Intune exécutée en contexte système.

    Historique des versions :

    1.0 - 03/09/2026
    - Version initiale.
#>

[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$DisplayNameLike = '',     # Modifier le nom de l'application ici

    [version]$TargetVersion = ''   # Modifier la version de l'application ici
)

function ConvertTo-Version {
    param (
        [AllowNull()]
        [AllowEmptyString()]
        [string]$VersionString
    )

    if ([string]::IsNullOrWhiteSpace($VersionString)) {
        return $null
    }

    # Extrait une version numérique, par exemple :
    # "9.5.3"     -> "9.5.3"
    # "ab 9.5.3"  -> "9.5.3"
    # "v9.5.3"    -> "9.5.3"
    if ($VersionString -match '\d+(?:\.\d+)+') {
        $CleanVersion = $Matches[0]

        [version]$ParsedVersion = $null

        if ([version]::TryParse($CleanVersion, [ref]$ParsedVersion)) {
            return $ParsedVersion
        }
    }

    return $null
}

$ErrorActionPreference = 'Stop'
$ExitCode = 1

try {

    $UninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $Packages = foreach ($RegistryPath in $UninstallPaths) {
        Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -and
                $_.DisplayName.IndexOf(
                    $DisplayNameLike,
                    [StringComparison]::OrdinalIgnoreCase
                ) -ge 0
            }
    }

    if (-not $Packages) {
        Write-Host "[$(Get-Date -Format s)] Application '$DisplayNameLike' introuvable"

    } else {
        $ValidPackages = foreach ($Package in $Packages) {
            $InstalledVersion = ConvertTo-Version $Package.DisplayVersion

            if ($InstalledVersion) {
                [PSCustomObject]@{
                    DisplayName = $Package.DisplayName
                    PackageId   = $Package.PSChildName
                    Publisher   = $Package.Publisher
                    Version     = $InstalledVersion
                }
            }
        }

        if (-not $ValidPackages) {
            Write-Host "[$(Get-Date -Format s)] Version installée invalide pour '$DisplayNameLike'"

        } else {
            $InstalledPackage = $ValidPackages |
                Sort-Object Version -Descending |
                Select-Object -First 1

            Write-Host "[$(Get-Date -Format s)] Application : $($InstalledPackage.DisplayName)"
            Write-Host "[$(Get-Date -Format s)] PackageId   : $($InstalledPackage.PackageId)"
            Write-Host "[$(Get-Date -Format s)] Éditeur     : $($InstalledPackage.Publisher)"
            Write-Host "[$(Get-Date -Format s)] Installée   : $($InstalledPackage.Version)"
            Write-Host "[$(Get-Date -Format s)] Cible       : $TargetVersion"

            if ($InstalledPackage.Version -ge $TargetVersion) {
                Write-Output "Application détectée : $($InstalledPackage.DisplayName) $($InstalledPackage.Version)"
                $ExitCode = 0
            } else {
                Write-Host "[$(Get-Date -Format s)] Mise à jour requise"
            }
        }
    }

} catch {
    Write-Error "[$(Get-Date -Format s)] Erreur lors de la détection de '$DisplayNameLike'"
    Write-Error "[$(Get-Date -Format s)] Erreur : $($_.Exception.Message)"
    $ExitCode = 1
} 

exit $ExitCode
