<#
.SYNOPSIS
    Tests du skill nouvelle-migration, dans un dossier temporaire (le dépôt n'est pas modifié).
    Code de sortie : 0 réussi, 1 échec.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$racine = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script = Join-Path $racine '.github/skills/nouvelle-migration/nouvelle-migration.ps1'
$moteur = (Get-Process -Id $PID).Path
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

$temporaire = Join-Path ([IO.Path]::GetTempPath()) ('nouvelle-migration-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
    $migrations = Join-Path $temporaire 'migrations'
    New-Item -ItemType Directory -Path $migrations -Force | Out-Null
    foreach ($nom in @('V1__a.sql', 'V2__b.sql', 'V10__c.sql', 'R__etl_x.sql')) { Set-Content -LiteralPath (Join-Path $migrations $nom) -Value '-- vide' }

    $apercu = Invoke-Skill @('-Description', 'ajouter_courriel_client', '-Racine', $temporaire)
    Test-Attente 'Aperçu : V11 après V10 (tri numérique, R__ ignorée)' (($apercu.Code -eq 0) -and ($apercu.Texte -match 'V11__ajouter_courriel_client\.sql')) $apercu.Texte
    Test-Attente 'Aperçu : aucun fichier créé' (-not (Test-Path (Join-Path $migrations 'V11__ajouter_courriel_client.sql')))

    $creation = Invoke-Skill @('-Description', 'ajouter_courriel_client', '-Creer', '-Racine', $temporaire)
    $cheminMigration = Join-Path $migrations 'V11__ajouter_courriel_client.sql'
    $cheminTest = Join-Path $temporaire 'tests/sql/test_ajouter_courriel_client.sql'
    Test-Attente 'Création : migration et test créés' (($creation.Code -eq 0) -and (Test-Path $cheminMigration) -and (Test-Path $cheminTest)) $creation.Texte
    if (Test-Path $cheminTest) {
        $contenuTest = [IO.File]::ReadAllText($cheminTest)
        Test-Attente 'Création : test dans une transaction annulée' (($contenuTest -match 'BEGIN TRANSACTION') -and ($contenuTest -match 'ROLLBACK TRANSACTION'))
    }

    $deuxieme = Invoke-Skill @('-Description', 'autre_sujet', '-Creer', '-Racine', $temporaire)
    Test-Attente 'Déterminisme : la création suivante prend V12' (($deuxieme.Code -eq 0) -and ($deuxieme.Texte -match 'V12__autre_sujet'))
    $refus = Invoke-Skill @('-Description', 'autre_sujet', '-Creer', '-Racine', $temporaire)
    Test-Attente 'Refus si le test existe déjà (aucun écrasement)' (($refus.Code -ne 0) -and ($refus.Texte -match 'existe déjà') -and -not (Test-Path (Join-Path $migrations 'V13__autre_sujet.sql')))

    $invalide = Invoke-Skill @('-Description', 'Ajouter Courriel', '-Racine', $temporaire)
    Test-Attente 'Description hors snake_case refusée' ($invalide.Code -ne 0)

    Set-Content -LiteralPath (Join-Path $migrations 'V13__doublon_a.sql') -Value '-- vide'
    Set-Content -LiteralPath (Join-Path $migrations 'V13__doublon_b.sql') -Value '-- vide'
    $doublon = Invoke-Skill @('-Description', 'apres_doublon', '-Racine', $temporaire)
    Test-Attente 'Numéros en double détectés' (($doublon.Code -ne 0) -and ($doublon.Texte -match 'double'))
}
finally {
    Remove-Item -LiteralPath $temporaire -Recurse -Force -ErrorAction SilentlyContinue
}

$depot = Invoke-Skill @('-Description', 'verification')
$versionsDepot = @(Get-ChildItem (Join-Path $racine 'migrations') -Filter 'V*__*.sql' | ForEach-Object { [int]($_.Name -replace '^V(\d+)__.*$', '$1') })
$attendu = ($versionsDepot | Measure-Object -Maximum).Maximum + 1
Test-Attente "Dépôt : prochaine version V$attendu" ($depot.Texte -match "Prochaine version : V$attendu\b") $depot.Texte

if ($echecs -gt 0) { Write-Output "$echecs attente(s) en échec."; exit 1 }
exit 0
