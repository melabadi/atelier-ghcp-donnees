<#
.SYNOPSIS
    Lit ou commente un billet Jira (Cloud ou Data Center) par l'API REST.

.DESCRIPTION
    Variables lues dans l'environnement ou dans .env (à la racine du dépôt) :
      JIRA_URL          p. ex. https://mon-espace.atlassian.net ou https://jira.exemple.local
      JIRA_DEPLOIEMENT  cloud ou datacenter
      JIRA_COURRIEL     courriel du compte (Cloud seulement)
      JIRA_JETON        jeton d'API (Cloud) ou jeton d'accès personnel (Data Center)
    Cloud       : Basic courriel:jeton, API v3, textes en Atlassian Document Format (ADF).
    Data Center : Bearer PAT, API v2, textes en texte brut (wiki).
    Le jeton n'est jamais affiché, même en cas d'erreur.

    -Simulation utilise les réponses enregistrées de tests/fixtures/ (aucun appel réseau).

.EXAMPLE
    pwsh ./.github/skills/jira-ticket/jira-ticket.ps1 -Action Lire -Cle ATL-1
.EXAMPLE
    pwsh ./.github/skills/jira-ticket/jira-ticket.ps1 -Action Commenter -Cle ATL-1 -Commentaire "Terminé" -Simulation
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Lire', 'Commenter')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z][A-Z0-9_]+-\d+$')]
    [string]$Cle,

    [string]$Commentaire,

    [switch]$Simulation,

    [string]$Racine
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Racine) { $Racine = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { Write-Verbose 'Encodage console inchangé.' }

function Import-FichierEnv {
    param([string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) { return }
    foreach ($ligne in [IO.File]::ReadAllLines($Chemin, [Text.Encoding]::UTF8)) {
        if ($ligne -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $valeur = $Matches[2].Trim().Trim('"', "'")
            if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($Matches[1])) -and $valeur) {
                [Environment]::SetEnvironmentVariable($Matches[1], $valeur)
            }
        }
    }
}

function Get-Propriete {
    param($Objet, [string]$Nom)
    if ($null -eq $Objet) { return $null }
    $propriete = $Objet.PSObject.Properties[$Nom]
    if ($propriete) { return $propriete.Value }
    return $null
}

function Get-MessageErreurHttp {
    param([int]$Statut)
    switch ($Statut) {
        401 { return 'Erreur 401 : authentification refusée. Vérifiez JIRA_JETON (et JIRA_COURRIEL en Cloud) dans .env, ainsi que JIRA_DEPLOIEMENT.' }
        403 { return "Erreur 403 : accès refusé. Le compte n'a pas le droit de voir ou de commenter ce billet." }
        404 { return "Erreur 404 : billet $Cle introuvable (ou invisible pour ce compte). Vérifiez la clé et JIRA_URL." }
        default { return "Erreur HTTP $Statut renvoyée par Jira." }
    }
}

function Get-StatutHttp {
    param($Erreur)
    $reponse = $null
    if ($Erreur.Exception.PSObject.Properties['Response']) { $reponse = $Erreur.Exception.Response }
    if ($reponse -and $reponse.PSObject.Properties['StatusCode']) { return [int]$reponse.StatusCode }
    return 0
}

# Convertit un nœud Atlassian Document Format (ADF) en texte brut.
function ConvertFrom-Adf {
    param($Noeud)
    if ($null -eq $Noeud) { return '' }
    if ($Noeud -is [string]) { return $Noeud }
    $type = [string](Get-Propriete $Noeud 'type')
    if ($type -eq 'text') { return [string](Get-Propriete $Noeud 'text') }
    if ($type -eq 'hardBreak') { return "`n" }
    $enfants = @(Get-Propriete $Noeud 'content' | Where-Object { $null -ne $_ })
    $morceaux = foreach ($enfant in $enfants) {
        $texte = ConvertFrom-Adf $enfant
        if ((Get-Propriete $enfant 'type') -eq 'listItem') { "- $($texte.Trim())`n" } else { $texte }
    }
    $resultat = -join $morceaux
    if ($type -in @('paragraph', 'heading', 'codeBlock', 'blockquote')) { $resultat += "`n" }
    return $resultat
}

# Construit un document ADF minimal : un paragraphe par ligne non vide.
function New-DocumentAdf {
    param([string]$Texte)
    $paragraphes = foreach ($ligne in ($Texte -split "`r?`n")) {
        if ($ligne.Trim()) { @{ type = 'paragraph'; content = @(@{ type = 'text'; text = $ligne }) } }
    }
    return @{ type = 'doc'; version = 1; content = @($paragraphes) }
}

function Get-ConfigurationJira {
    param([string]$Deploiement)
    if ($Deploiement -eq 'cloud') {
        $paire = '{0}:{1}' -f $env:JIRA_COURRIEL, $env:JIRA_JETON
        return @{ Version = '3'; Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($paire)) }
    }
    return @{ Version = '2'; Authorization = "Bearer $($env:JIRA_JETON)" }
}

function Get-TexteChamp {
    param($Valeur, [string]$Deploiement)
    if ($null -eq $Valeur) { return '(vide)' }
    $texte = if ($Deploiement -eq 'cloud') { ConvertFrom-Adf $Valeur } else { [string]$Valeur }
    $texte = ($texte -split "`r?`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ }) -join "`n"
    if ([string]::IsNullOrWhiteSpace($texte)) { return '(vide)' }
    return $texte
}

function Read-Fixture {
    param([string]$Nom)
    $chemin = Join-Path (Join-Path $Racine 'tests/fixtures') $Nom
    if (-not (Test-Path -LiteralPath $chemin)) {
        throw "Simulation : aucune réponse enregistrée ($Nom). Billet disponible : ATL-1."
    }
    $json = [IO.File]::ReadAllText($chemin, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $statut = Get-Propriete $json 'statutHttpSimule'
    if ($statut) { [Console]::Error.WriteLine((Get-MessageErreurHttp ([int]$statut))); exit 1 }
    return $json
}

function Invoke-ApiJira {
    param([string]$Methode, [string]$Url, [string]$Authorization, [string]$Corps)
    $parametres = @{
        Method  = $Methode
        Uri     = $Url
        Headers = @{ Authorization = $Authorization; Accept = 'application/json' }
    }
    if ($Corps) {
        $parametres.ContentType = 'application/json; charset=utf-8'
        $parametres.Body = [Text.Encoding]::UTF8.GetBytes($Corps)
    }
    try { return Invoke-RestMethod @parametres }
    catch {
        $statut = Get-StatutHttp $_
        if ($statut -gt 0) { [Console]::Error.WriteLine((Get-MessageErreurHttp $statut)) }
        else { [Console]::Error.WriteLine('Erreur réseau : Jira est injoignable (proxy, VPN?). Réessayez avec -Simulation.') }
        exit 1
    }
}

if ($Action -eq 'Commenter' -and [string]::IsNullOrWhiteSpace($Commentaire)) {
    [Console]::Error.WriteLine('Le paramètre -Commentaire est requis pour -Action Commenter.')
    exit 1
}

Import-FichierEnv (Join-Path $Racine '.env')
$deploiement = ([string]$env:JIRA_DEPLOIEMENT).Trim().ToLowerInvariant()
if (-not $deploiement) { $deploiement = 'cloud' }
if ($deploiement -notin @('cloud', 'datacenter')) {
    [Console]::Error.WriteLine("JIRA_DEPLOIEMENT doit valoir cloud ou datacenter (valeur reçue : $deploiement).")
    exit 1
}

$configuration = $null
$urlApi = $null
if (-not $Simulation) {
    $requises = @('JIRA_URL', 'JIRA_JETON')
    if ($deploiement -eq 'cloud') { $requises += 'JIRA_COURRIEL' }
    $manquantes = $requises | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_)) }
    if ($manquantes) {
        [Console]::Error.WriteLine("Variables manquantes dans .env : $($manquantes -join ', '). Copiez .env.example en .env, ou utilisez -Simulation.")
        exit 1
    }
    $configuration = Get-ConfigurationJira $deploiement
    $urlApi = '{0}/rest/api/{1}/issue/{2}' -f $env:JIRA_URL.TrimEnd('/'), $configuration.Version, $Cle
}

try {
    if ($Action -eq 'Lire') {
        if ($Simulation) {
            $billet = Read-Fixture "jira-$deploiement-$Cle.json"
            Write-Output "[Simulation $deploiement] Réponse enregistrée, aucun appel réseau."
        }
        else {
            $billet = Invoke-ApiJira -Methode 'GET' -Url "${urlApi}?fields=summary,status,issuetype,description" -Authorization $configuration.Authorization
        }
        $champs = $billet.fields
        $statut = Get-Propriete $champs 'status'
        $type = Get-Propriete $champs 'issuetype'
        Write-Output ("Billet {0} ({1}) : {2}" -f $billet.key, (Get-Propriete $type 'name'), (Get-Propriete $champs 'summary'))
        Write-Output ("État : {0}" -f (Get-Propriete $statut 'name'))
        Write-Output 'Description :'
        Write-Output (Get-TexteChamp (Get-Propriete $champs 'description') $deploiement)
    }
    else {
        $corps = if ($deploiement -eq 'cloud') { @{ body = (New-DocumentAdf $Commentaire) } } else { @{ body = $Commentaire } }
        $json = $corps | ConvertTo-Json -Depth 10 -Compress
        if ($Simulation) {
            $reponse = Read-Fixture "jira-commentaire-$deploiement.json"
            $version = if ($deploiement -eq 'cloud') { '3' } else { '2' }
            Write-Output "[Simulation $deploiement] Aucun appel réseau. Requête qui serait envoyée :"
            Write-Output "POST {JIRA_URL}/rest/api/$version/issue/$Cle/comment"
            Write-Output "Corps : $json"
        }
        else {
            $reponse = Invoke-ApiJira -Methode 'POST' -Url "$urlApi/comment" -Authorization $configuration.Authorization -Corps $json
        }
        Write-Output ("Commentaire {0} ajouté au billet {1}." -f $reponse.id, $Cle)
    }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
exit 0
