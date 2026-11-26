<#
.SYNOPSIS
    Vérifie le poste avant l'atelier, sans rien installer.

.DESCRIPTION
    Contrôle la présence et la version de Git, PowerShell, Docker (démon actif), Flyway,
    Python et sqlfluff, sqlcmd, VS Code et GitHub Copilot CLI. Les outils requis dépendent
    du mode de validation prévu (voir scripts/valider.ps1). Indique la marche à suivre et
    si le hook de garde-fous peut être activé (PowerShell 7 présent).

    Code de sortie 0 si tous les outils requis pour le mode sont présents, sinon 1.

.EXAMPLE
    pwsh ./scripts/verifier-poste.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\verifier-poste.ps1 -Mode Local
#>
[CmdletBinding()]
param(
    [ValidateSet('Docker', 'Local', 'LintSeulement')]
    [string]$Mode = 'Docker',
    [ValidateSet('Flyway', 'SqlcmdInitial')]
    [string]$MethodeSchema = 'Flyway'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { Write-Verbose 'Encodage console inchangé.' }

function Get-PremiereLigne {
    param([string]$Executable, [string[]]$Arguments)
    if (-not (Get-Command $Executable -CommandType Application -ErrorAction SilentlyContinue)) { return $null }
    $preferencePrecedente = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $sortie = & $Executable @Arguments 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ }
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($sortie | Select-Object -First 1)
    }
    catch { return $null }
    finally { $ErrorActionPreference = $preferencePrecedente }
}

$pwsh7 = Get-PremiereLigne 'pwsh' @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
$python = Get-PremiereLigne 'python3' @('--version')
if (-not $python) { $python = Get-PremiereLigne 'python' @('--version') }
$sqlfluff = Get-PremiereLigne 'sqlfluff' @('--version')
if (-not $sqlfluff) {
    $sqlfluff = Get-PremiereLigne 'python' @('-m', 'sqlfluff', '--version')
    if (-not $sqlfluff) { $sqlfluff = Get-PremiereLigne 'python3' @('-m', 'sqlfluff', '--version') }
}
$dockerClient = Get-PremiereLigne 'docker' @('--version')
$dockerDemon = if ($dockerClient) { Get-PremiereLigne 'docker' @('version', '--format', '{{.Server.Version}}') } else { $null }
$flyway = Get-PremiereLigne 'flyway' @('-v')
if ($flyway) { $flyway = ($flyway -replace '^.*?(Flyway)', '$1') }
$sqlcmd = Get-PremiereLigne 'sqlcmd' @('-?')
$pythonCommande = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
$pytest = Get-PremiereLigne $pythonCommande @('-m', 'pytest', '--version')
$odbc = Get-PremiereLigne $pythonCommande @('-c',
    "import pyodbc, os, sys; d=os.getenv('PYTEST_ODBC_DRIVER','ODBC Driver 18 for SQL Server'); print(d) if d in pyodbc.drivers() else sys.exit(1)")

$verifications = @(
    [pscustomobject]@{ Outil = 'Git'; Version = (Get-PremiereLigne 'git' @('--version')); Requis = $true
        Conseil = 'Installez Git : https://git-scm.com/downloads' }
    [pscustomobject]@{ Outil = 'PowerShell (session courante)'; Version = "PowerShell $($PSVersionTable.PSVersion)"; Requis = $true; Conseil = '' }
    [pscustomobject]@{ Outil = 'PowerShell 7 (pwsh)'; Version = $(if ($pwsh7) { "pwsh $pwsh7" }); Requis = $false
        Conseil = 'Requis seulement pour activer le hook : https://learn.microsoft.com/powershell/scripting/install/installing-powershell' }
    [pscustomobject]@{ Outil = 'Python'; Version = $python; Requis = $true
        Conseil = 'Installez Python 3 : https://www.python.org/downloads/' }
    [pscustomobject]@{ Outil = 'sqlfluff'; Version = $sqlfluff; Requis = $true
        Conseil = 'pip install -r requirements-dev.txt' }
    [pscustomobject]@{ Outil = 'pytest'; Version = $pytest; Requis = ($Mode -ne 'LintSeulement')
        Conseil = 'python -m pip install -r requirements-dev.txt' }
    [pscustomobject]@{ Outil = 'pyodbc + pilote SQL Server'; Version = $odbc; Requis = ($Mode -ne 'LintSeulement')
        Conseil = 'Installer Microsoft ODBC Driver 18; ou définir PYTEST_ODBC_DRIVER pour un pilote 17 déjà installé' }
    [pscustomobject]@{ Outil = 'Docker (démon actif)'; Version = $(if ($dockerDemon) { "$dockerClient, démon $dockerDemon" }); Requis = ($Mode -eq 'Docker')
        Conseil = $(if ($dockerClient) { 'Démarrez Docker Desktop (le démon ne répond pas)' } else { 'Installez Docker, ou utilisez -Mode Local ou -Mode LintSeulement' }) }
    [pscustomobject]@{ Outil = 'Flyway (CLI)'; Version = $flyway; Requis = ($Mode -eq 'Local' -and $MethodeSchema -eq 'Flyway')
        Conseil = $(if ($Mode -eq 'Docker') { 'Facultatif en mode Docker : l''image redgate/flyway est utilisée' } else { 'Installez Flyway Community : https://documentation.red-gate.com/fd' }) }
    [pscustomobject]@{ Outil = 'sqlcmd'; Version = $(if ($sqlcmd) { 'présent' }); Requis = ($Mode -eq 'Local')
        Conseil = 'Installez go-sqlcmd : https://learn.microsoft.com/sql/tools/sqlcmd/go-sqlcmd-utility' }
    [pscustomobject]@{ Outil = 'VS Code'; Version = (Get-PremiereLigne 'code' @('--version')); Requis = $true
        Conseil = 'Installez VS Code et l''extension GitHub Copilot Chat : https://code.visualstudio.com/' }
    [pscustomobject]@{ Outil = 'GitHub Copilot CLI'; Version = (Get-PremiereLigne 'copilot' @('--version')); Requis = $false
        Conseil = 'Surface de repli pour la démo du hook : https://docs.github.com/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli' }
)

Write-Host "Vérification du poste - mode de validation prévu : $Mode"
Write-Host ''
$manquants = 0
foreach ($v in $verifications) {
    if ($v.Version) {
        Write-Host ("[OK]        {0,-30} {1}" -f $v.Outil, $v.Version) -ForegroundColor Green
    }
    elseif ($v.Requis) {
        $manquants++
        Write-Host ("[MANQUANT]  {0,-30} {1}" -f $v.Outil, $v.Conseil) -ForegroundColor Red
    }
    else {
        Write-Host ("[OPTIONNEL] {0,-30} {1}" -f $v.Outil, $v.Conseil) -ForegroundColor Yellow
    }
}

Write-Host ''
if ($pwsh7) { Write-Host 'Hook : PowerShell 7 présent, le hook de garde-fous peut être activé.' -ForegroundColor Green }
else { Write-Host 'Hook : PowerShell 7 absent. Ne l''activez pas : un hook en échec refuserait tous les outils.' -ForegroundColor Yellow }

if ($Mode -eq 'Local') {
    if ($MethodeSchema -eq 'Flyway') {
        Write-Host 'Mode Local/Flyway : connexion TCP/IP (JDBC); faire configurer TCP/port par l''administrateur.'
    }
    else { Write-Host 'Mode Local/SqlcmdInitial : instantané sur une base neuve; mémoire partagée acceptée, aucun historique Flyway.' }
}

Write-Host ''
if ($manquants -gt 0) {
    Write-Host "$manquants outil(s) requis manquant(s) pour le mode $Mode." -ForegroundColor Red
    if ($Mode -ne 'LintSeulement') { Write-Host 'Repli possible : pwsh ./scripts/valider.ps1 -Mode LintSeulement' }
    exit 1
}
Write-Host "Poste prêt pour : pwsh ./scripts/valider.ps1 -Mode $Mode -MethodeSchema $MethodeSchema" -ForegroundColor Green
exit 0
