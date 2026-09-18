<#
.SYNOPSIS
    Installe ou désinstalle une application via WinGet.

.DESCRIPTION
    Ce script permet d'installer ou de désinstaller une application à partir
    de son identifiant WinGet.

    Lors d'une installation :
    - si aucune version n'est précisée, WinGet installe la dernière version disponible ;
    - si une version est précisée avec -Version, cette version spécifique est installée ;
    - des paramètres supplémentaires peuvent être transmis à l'installeur avec -OverrideParams.

    Attention :
    l'utilisation de -OverrideParams entraîne l'utilisation de l'option WinGet --override.
    Cette option remplace les arguments d'installation définis dans le manifeste WinGet.
    Il est donc nécessaire de connaître les paramètres réellement supportés par
    l'installeur sous-jacent (MSI, EXE, Inno Setup, NSIS, etc.).

    Les paramètres tels que /qn, /quiet ou /norestart ne sont pas universels.

.EXAMPLE
    .\WinGet.ps1 -PackageId 'Microsoft.PowerBI'

    Installe la dernière version disponible de Microsoft Power BI.

.EXAMPLE
    .\WinGet.ps1 -PackageId 'Microsoft.PowerBI' -Version '2.146.1254.0'

    Installe la version 2.146.1254.0 de Microsoft Power BI.

.EXAMPLE
    .\WinGet.ps1 -Action Uninstall -PackageId 'Microsoft.PowerBI'

    Désinstalle Microsoft Power BI.

.EXAMPLE
    .\WinGet.ps1 -PackageId 'Nom.Editeur.Application' `
        -OverrideParams '/qn REBOOT=ReallySuppress ALLUSERS=1'

    Installe l'application en transmettant des paramètres personnalisés
    directement à l'installeur via WinGet --override.

.PARAMETER Action
    Action à effectuer.
    Valeurs possibles : Install ou Uninstall.
    Valeur par défaut : Install.

.PARAMETER PackageId
    Identifiant exact du package WinGet.

.PARAMETER Version
    Version spécifique à installer.
    Si ce paramètre n'est pas renseigné, la dernière version disponible est utilisée.
    Ce script n'utilise ce paramètre que pour l'action Install.

.PARAMETER OverrideParams
    Chaîne de paramètres supplémentaires transmise directement à l'installeur
    via WinGet --override.

    Sa syntaxe dépend entièrement du type d'installeur utilisé par le package.
    Ce script n'utilise ce paramètre que pour l'action Install.

.PARAMETER LogDir
    Répertoire contenant le journal d'exécution.
    Par défaut :
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs

.NOTES
    Auteur               : Matthieu Dasnoy
    Date de création     : 03/09/2026
    Dernière modification: 03/09/2026
    Version              : 1.0

    Le script est prévu pour un usage automatisé, notamment avec Microsoft Intune.
#>

[CmdletBinding()]
param (       
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install',           
    
    [Parameter(Mandatory)]         
    [string]$PackageId,

    [string]$Version,

    [string]$OverrideParams,
    
    [string]$LogDir = (Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs')
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
$ExitCode = 1
$TranscriptStarted = $false

try {
    # Transcript 
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }

    $SafePackageId = ($PackageId -replace '[\\/:*?"<>|]', '_')
    $SafeAction = $Action.ToLower()
    $LogPath = Join-Path $LogDir "winget_${SafePackageId}_${SafeAction}.log"

    Start-Transcript -Path $LogPath -Force -Append
    $TranscriptStarted = $true

    $WinGetExe = Get-WinGetExecutable
    Write-Output "[$(Get-Date -Format s)] WinGet opérationnel"

    $WinGetArgs = @(
        $Action.ToLower(),  
        '--id', $PackageId,
        '--exact',
        '--accept-source-agreements',
        '--silent',
        '--disable-interactivity',
        '--scope', 'machine'
    )

    if ($Action -eq 'Install') {
        $WinGetArgs += @('--accept-package-agreements')

        if ($Version) {
            $WinGetArgs += @('--version', $Version)
        }

        if ($OverrideParams) {
            $WinGetArgs += @('--override', $OverrideParams)
        }
    }

    Write-Output "[$(Get-Date -Format s)] Exécution de la commande : $WinGetExe $($WinGetArgs -join ' ')"

    & $WinGetExe $WinGetArgs

    $AppExitCode = $LASTEXITCODE

    if ($Action -eq 'Install') {

        switch ($AppExitCode) {
            0 {
                Write-Output "[$(Get-Date -Format s)] Installation de $PackageId terminée avec succès"
                $ExitCode = 0
            }

            -1978335189 {
                Write-Output "[$(Get-Date -Format s)] Aucune installation ou mise à jour applicable pour $PackageId"
                $ExitCode = 0
            }

            -1978335135 {
                Write-Output "[$(Get-Date -Format s)] $PackageId est déjà installé"
                $ExitCode = 0
            }

            default {
                Write-Output "[$(Get-Date -Format s)] Installation de $PackageId échouée (exit code: $AppExitCode)"
                $ExitCode = 1
            }
        }

    } else {

        switch ($AppExitCode) {
            0 {
                Write-Output "[$(Get-Date -Format s)] Désinstallation de $PackageId terminée avec succès"
                $ExitCode = 0
            }

            -1978335212 {
                Write-Output "[$(Get-Date -Format s)] $PackageId n'est pas installé"
                $ExitCode = 0
            }

            default {
                Write-Output "[$(Get-Date -Format s)] Désinstallation de $PackageId échouée (exit code: $AppExitCode)"
                $ExitCode = 1
            }
        }
    }
        
} catch {
    Write-Output "[$(Get-Date -Format s)] Erreur lors de winget $Action $PackageId"
    Write-Output "[$(Get-Date -Format s)] Erreur : $($_.Exception.Message)"
    $ExitCode = 1

} finally {
    if ($TranscriptStarted) {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }
}

exit $ExitCode
