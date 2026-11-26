<#
.SYNOPSIS
    Tests du skill jira-ticket en mode -Simulation (aucun appel réseau), Cloud et Data Center.
    Code de sortie : 0 réussi, 1 échec, 2 en attente (le script contient encore des marqueurs TODO-ATELIER).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$racine = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script = Join-Path $racine '.github/skills/jira-ticket/jira-ticket.ps1'
$moteur = (Get-Process -Id $PID).Path

$marqueurs = @(Select-String -LiteralPath $script -Pattern '#\s*TODO-ATELIER' -SimpleMatch:$false)
if ($marqueurs.Count -gt 0) {
    Write-Output "  En attente : $($marqueurs.Count) marqueur(s) TODO-ATELIER à compléter dans jira-ticket.ps1 (atelier, ou branche etape-2)."
    exit 2
}

$jetonFactice = 'jeton-factice-' + [guid]::NewGuid().ToString('N')
$env:JIRA_JETON = $jetonFactice
$env:JIRA_COURRIEL = 'personne@exemple.com'
$env:JIRA_URL = 'https://espace-fictif.atlassian.net'
$echecs = 0
$sorties = New-Object System.Collections.Generic.List[string]

function Invoke-Skill {
    param([string]$Deploiement, [string[]]$Arguments)
    $env:JIRA_DEPLOIEMENT = $Deploiement
    $sortie = & $moteur -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script @Arguments 2>&1 | ForEach-Object { "$_" }
    $texte = $sortie -join "`n"
    $script:sorties.Add($texte)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Texte = $texte }
}

function Test-Attente {
    param([string]$Nom, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Output "  [OK] $Nom" }
    else { $script:echecs++; Write-Output "  [ECHEC] $Nom $Detail" }
}

foreach ($deploiement in @('cloud', 'datacenter')) {
    $lire = Invoke-Skill $deploiement @('-Action', 'Lire', '-Cle', 'ATL-1', '-Simulation')
    Test-Attente "${deploiement} Lire : code 0 et résumé" (($lire.Code -eq 0) -and ($lire.Texte -match 'ATL-1 \(Story\) : Créer la vue rpt\.v_ventes_mensuelles')) $lire.Texte
    Test-Attente "${deploiement} Lire : description en texte" (($lire.Texte -match 'quantite_totale et montant_total') -and ($lire.Texte -notmatch '"type"'))
}

$listeCloud = Invoke-Skill 'cloud' @('-Action', 'Lire', '-Cle', 'ATL-1', '-Simulation')
Test-Attente 'cloud Lire : liste ADF rendue en puces' ($listeCloud.Texte -match '(?m)^- Elle est créée dans une migration répétable')

$commentaireCloud = Invoke-Skill 'cloud' @('-Action', 'Commenter', '-Cle', 'ATL-1', '-Commentaire', "Vue ajoutée.`nCI verte.", '-Simulation')
Test-Attente 'cloud Commenter : API v3 et corps ADF' (($commentaireCloud.Code -eq 0) -and ($commentaireCloud.Texte -match '/rest/api/3/issue/ATL-1/comment') -and ($commentaireCloud.Texte -match '"type":"doc"') -and ($commentaireCloud.Texte -match '"version":1')) $commentaireCloud.Texte
Test-Attente 'cloud Commenter : un paragraphe par ligne' (([regex]::Matches($commentaireCloud.Texte, '"type":"paragraph"')).Count -eq 2)

$commentaireDc = Invoke-Skill 'datacenter' @('-Action', 'Commenter', '-Cle', 'ATL-1', '-Commentaire', 'Vue ajoutée.', '-Simulation')
Test-Attente 'datacenter Commenter : API v2 et {"body": texte}' (($commentaireDc.Code -eq 0) -and ($commentaireDc.Texte -match '/rest/api/2/issue/ATL-1/comment') -and ($commentaireDc.Texte -match '"body":"Vue ajoutée\."')) $commentaireDc.Texte

$refus = Invoke-Skill 'cloud' @('-Action', 'Lire', '-Cle', 'ATL-401', '-Simulation')
Test-Attente 'Erreur 401 expliquée' (($refus.Code -ne 0) -and ($refus.Texte -match 'Erreur 401') -and ($refus.Texte -match 'JIRA_JETON'))

$cleInvalide = Invoke-Skill 'cloud' @('-Action', 'Lire', '-Cle', 'atl1', '-Simulation')
Test-Attente 'Clé invalide refusée' ($cleInvalide.Code -ne 0)

$deploiementInvalide = Invoke-Skill 'serveur' @('-Action', 'Lire', '-Cle', 'ATL-1', '-Simulation')
Test-Attente 'JIRA_DEPLOIEMENT invalide refusé' (($deploiementInvalide.Code -ne 0) -and ($deploiementInvalide.Texte -match 'cloud ou datacenter'))

Test-Attente 'Le jeton factice ne paraît jamais dans la sortie' (-not (($sorties -join "`n").Contains($jetonFactice)))

if ($echecs -gt 0) { Write-Output "$echecs attente(s) en échec."; exit 1 }
exit 0
