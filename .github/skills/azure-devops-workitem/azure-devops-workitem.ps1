<#
.SYNOPSIS
    Lit ou commente un élément de travail Azure DevOps par l'API REST.

.DESCRIPTION
    Variables lues dans l'environnement ou dans .env (à la racine du dépôt) :
      ADO_ORG_URL  p. ex. https://dev.azure.com/mon-organisation
      ADO_PROJET   nom du projet
      ADO_PAT      jeton d'accès personnel (portée Work Items, lecture et écriture)
    Le jeton n'est jamais affiché, même en cas d'erreur.

    -Simulation utilise les réponses enregistrées de tests/fixtures/ (aucun appel réseau).

.EXAMPLE
    pwsh ./.github/skills/azure-devops-workitem/azure-devops-workitem.ps1 -Action Lire -Id 42
.EXAMPLE
    pwsh ./.github/skills/azure-devops-workitem/azure-devops-workitem.ps1 -Action Commenter -Id 42 -Commentaire "Terminé" -Simulation
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Lire', 'Commenter')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$Id,

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

# Convertit le HTML des champs Azure DevOps en texte brut lisible.
function ConvertTo-TexteBrut {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return '(vide)' }
    $texte = $Html -replace '(?i)<br\s*/?>', "`n"
    $texte = $texte -replace '(?i)<li[^>]*>', "`n- "
    $texte = $texte -replace '(?i)</(p|div|li|h[1-6]|tr|ul|ol)>', "`n"
    $texte = $texte -replace '<[^>]+>', ''
    $texte = [Net.WebUtility]::HtmlDecode($texte)
    $lignes = $texte -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    return ($lignes -join "`n")
}

function Get-ValeurChamp {
    param($Champs, [string]$Nom)
    $propriete = $Champs.PSObject.Properties[$Nom]
    if ($propriete) { return [string]$propriete.Value }
    return ''
}

function Get-MessageErreurHttp {
    param([int]$Statut)
    switch ($Statut) {
        401 { return 'Erreur 401 : authentification refusée. Vérifiez ADO_PAT dans .env (absent, expiré ou mal copié).' }
        403 { return 'Erreur 403 : accès refusé. Le PAT doit avoir la portée Work Items (lecture et écriture) sur ce projet.' }
        404 { return "Erreur 404 : élément $Id introuvable. Vérifiez le numéro, ADO_ORG_URL et ADO_PROJET." }
        default { return "Erreur HTTP $Statut renvoyée par Azure DevOps." }
    }
}

function Get-StatutHttp {
    param($Erreur)
    $reponse = $null
    if ($Erreur.Exception.PSObject.Properties['Response']) { $reponse = $Erreur.Exception.Response }
    if ($reponse -and $reponse.PSObject.Properties['StatusCode']) { return [int]$reponse.StatusCode }
    return 0
}

function Read-Fixture {
    param([string]$Nom)
    $chemin = Join-Path (Join-Path $Racine 'tests/fixtures') $Nom
    if (-not (Test-Path -LiteralPath $chemin)) {
        throw "Simulation : aucune réponse enregistrée ($Nom). Éléments disponibles : 42."
    }
    $json = [IO.File]::ReadAllText($chemin, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($json.PSObject.Properties['statutHttpSimule']) {
        [Console]::Error.WriteLine((Get-MessageErreurHttp ([int]$json.statutHttpSimule)))
        exit 1
    }
    return $json
}

function Invoke-ApiAzureDevOps {
    param([string]$Methode, [string]$Url, [string]$Corps)
    $authentification = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($env:ADO_PAT)"))
    $parametres = @{
        Method  = $Methode
        Uri     = $Url
        Headers = @{ Authorization = "Basic $authentification"; Accept = 'application/json' }
    }
    if ($Corps) {
        $parametres.ContentType = 'application/json; charset=utf-8'
        $parametres.Body = [Text.Encoding]::UTF8.GetBytes($Corps)
    }
    try { return Invoke-RestMethod @parametres }
    catch {
        $statut = Get-StatutHttp $_
        if ($statut -gt 0) { [Console]::Error.WriteLine((Get-MessageErreurHttp $statut)) }
        else { [Console]::Error.WriteLine('Erreur réseau : Azure DevOps est injoignable (proxy, VPN?). Réessayez avec -Simulation.') }
        exit 1
    }
}

if ($Action -eq 'Commenter' -and [string]::IsNullOrWhiteSpace($Commentaire)) {
    [Console]::Error.WriteLine('Le paramètre -Commentaire est requis pour -Action Commenter.')
    exit 1
}

$urlBase = $null
if (-not $Simulation) {
    Import-FichierEnv (Join-Path $Racine '.env')
    $manquantes = @('ADO_ORG_URL', 'ADO_PROJET', 'ADO_PAT') | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_)) }
    if ($manquantes) {
        [Console]::Error.WriteLine("Variables manquantes dans .env : $($manquantes -join ', '). Copiez .env.example en .env, ou utilisez -Simulation.")
        exit 1
    }
    $urlBase = '{0}/{1}/_apis/wit' -f $env:ADO_ORG_URL.TrimEnd('/'), [Uri]::EscapeDataString($env:ADO_PROJET)
}

try {
    if ($Action -eq 'Lire') {
        $element = if ($Simulation) { Read-Fixture "ado-workitem-$Id.json" }
        else { Invoke-ApiAzureDevOps -Methode 'GET' -Url "$urlBase/workitems/${Id}?api-version=7.1" }
        $champs = $element.fields
        if ($Simulation) { Write-Output '[Simulation] Réponse enregistrée, aucun appel réseau.' }
        Write-Output ("Élément de travail {0} ({1}) : {2}" -f $element.id, (Get-ValeurChamp $champs 'System.WorkItemType'), (Get-ValeurChamp $champs 'System.Title'))
        Write-Output ("État : {0}" -f (Get-ValeurChamp $champs 'System.State'))
        Write-Output 'Description :'
        Write-Output (ConvertTo-TexteBrut (Get-ValeurChamp $champs 'System.Description'))
        Write-Output "Critères d'acceptation :"
        Write-Output (ConvertTo-TexteBrut (Get-ValeurChamp $champs 'Microsoft.VSTS.Common.AcceptanceCriteria'))
    }
    else {
        $corps = @{ text = $Commentaire } | ConvertTo-Json -Compress
        if ($Simulation) {
            $reponse = Read-Fixture 'ado-commentaire.json'
            Write-Output '[Simulation] Aucun appel réseau. Requête qui serait envoyée :'
            Write-Output "POST {ADO_ORG_URL}/{ADO_PROJET}/_apis/wit/workItems/$Id/comments?format=markdown&api-version=7.1-preview.4"
            Write-Output "Corps : $corps"
        }
        else {
            $reponse = Invoke-ApiAzureDevOps -Methode 'POST' -Url "$urlBase/workItems/$Id/comments?format=markdown&api-version=7.1-preview.4" -Corps $corps
        }
        Write-Output ("Commentaire {0} ajouté à l'élément de travail {1}." -f $reponse.id, $Id)
    }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
exit 0
