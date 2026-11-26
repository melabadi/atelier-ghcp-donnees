<#
.SYNOPSIS
    Tests du skill azure-devops-workitem en mode -Simulation (aucun appel réseau).
    Code de sortie : 0 réussi, 1 échec.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$racine = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script = Join-Path $racine '.github/skills/azure-devops-workitem/azure-devops-workitem.ps1'
$moteur = (Get-Process -Id $PID).Path
$jetonFactice = 'jeton-factice-' + [guid]::NewGuid().ToString('N')
$env:ADO_PAT = $jetonFactice
$env:ADO_ORG_URL = 'https://dev.azure.com/organisation-fictive'
$env:ADO_PROJET = 'Projet fictif'
$echecs = 0

function Invoke-Skill {
    param([string[]]$Arguments)
    $sortie = & $moteur -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script @Arguments 2>&1 | ForEach-Object { "$_" }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Texte = ($sortie -join "`n") }
}

function Test-Attente {
    param([string]$Nom, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Output "  [OK] $Nom" }
    else { $script:echecs++; Write-Output "  [ECHEC] $Nom $Detail" }
}

$lire = Invoke-Skill @('-Action', 'Lire', '-Id', '42', '-Simulation')
Test-Attente 'Lire : code de sortie 0' ($lire.Code -eq 0) $lire.Texte
Test-Attente 'Lire : titre affiché' ($lire.Texte -match 'Retirer un produit du catalogue')
Test-Attente 'Lire : état affiché' ($lire.Texte -match 'État : Active')
Test-Attente "Lire : critères d'acceptation en texte brut" (($lire.Texte -match '- Une colonne est_actif') -and ($lire.Texte -notmatch '<[a-z]+'))
Test-Attente 'Lire : entités HTML décodées' ($lire.Texte -match "qu'un produit inactif")

$commenter = Invoke-Skill @('-Action', 'Commenter', '-Id', '42', '-Commentaire', 'Migration ajoutée, CI verte.', '-Simulation')
Test-Attente 'Commenter : code de sortie 0' ($commenter.Code -eq 0) $commenter.Texte
Test-Attente 'Commenter : requête montrée avec format=markdown' ($commenter.Texte -match 'format=markdown&api-version=7\.1-preview\.4')
Test-Attente 'Commenter : corps {"text"}' ($commenter.Texte -match '"text":"Migration ajoutée, CI verte\."')

$sansTexte = Invoke-Skill @('-Action', 'Commenter', '-Id', '42', '-Simulation')
Test-Attente 'Commenter sans -Commentaire : refusé' ($sansTexte.Code -ne 0)

$interdit = Invoke-Skill @('-Action', 'Lire', '-Id', '403', '-Simulation')
Test-Attente 'Erreur 403 expliquée' (($interdit.Code -ne 0) -and ($interdit.Texte -match 'Erreur 403') -and ($interdit.Texte -match 'Work Items'))

$inconnu = Invoke-Skill @('-Action', 'Lire', '-Id', '999', '-Simulation')
Test-Attente 'Élément sans réponse enregistrée : erreur claire' (($inconnu.Code -ne 0) -and ($inconnu.Texte -match 'aucune réponse enregistrée'))

$tout = @($lire, $commenter, $sansTexte, $interdit, $inconnu) | ForEach-Object { $_.Texte }
Test-Attente 'Le jeton factice ne paraît jamais dans la sortie' (-not (($tout -join "`n").Contains($jetonFactice)))

if ($echecs -gt 0) { Write-Output "$echecs attente(s) en échec."; exit 1 }
exit 0
