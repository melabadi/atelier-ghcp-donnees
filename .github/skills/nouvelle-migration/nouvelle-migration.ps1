<#
.SYNOPSIS
    Calcule le prochain numéro de migration Flyway et crée, sur demande, la migration et son test.

.DESCRIPTION
    Le numéro est déterministe : plus grand V<n> trouvé dans migrations/ + 1 (les trous sont ignorés).
    Sans -Creer, le script affiche seulement les noms de fichiers prévus.
    Avec -Creer, il crée migrations/V<n>__<description>.sql et tests/sql/test_<description>.sql
    à partir de modèles, sans jamais écraser un fichier existant.

.EXAMPLE
    pwsh ./.github/skills/nouvelle-migration/nouvelle-migration.ps1 -Description ajouter_courriel_client -Creer
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Description,

    [switch]$Creer,

    # Racine du dépôt (par défaut, trois niveaux au-dessus de ce script).
    [string]$Racine
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Racine) { $Racine = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }

function Get-ProchaineVersion {
    param([string]$DossierMigrations)
    $versions = @(Get-ChildItem -LiteralPath $DossierMigrations -Filter 'V*__*.sql' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^V(\d+)__' } |
        ForEach-Object { [int]($_.Name -replace '^V(\d+)__.*$', '$1') })
    $doublons = @($versions | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    if ($doublons.Count -gt 0) { throw "Numéros de version en double dans migrations/ : V$($doublons -join ', V'). Corrigez avant de continuer." }
    if ($versions.Count -eq 0) { return 1 }
    return (($versions | Measure-Object -Maximum).Maximum + 1)
}

if ($Description -cnotmatch '^[a-z][a-z0-9]*(_[a-z0-9]+)*$') {
    [Console]::Error.WriteLine('La description doit être en snake_case, sans accents ni majuscules (p. ex. ajouter_courriel_client).')
    exit 1
}

$dossierMigrations = Join-Path $Racine 'migrations'
$dossierTests = Join-Path $Racine 'tests/sql'
try { $version = Get-ProchaineVersion $dossierMigrations }
catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }

$nomMigration = "V${version}__$Description.sql"
$nomTest = "test_$Description.sql"
$cheminMigration = Join-Path $dossierMigrations $nomMigration
$cheminTest = Join-Path $dossierTests $nomTest

Write-Output "Prochaine version : V$version"
Write-Output "Migration : migrations/$nomMigration"
Write-Output "Test      : tests/sql/$nomTest"

if (-not $Creer) {
    Write-Output 'Aucun fichier créé (ajoutez -Creer pour les créer).'
    exit 0
}

foreach ($chemin in @($cheminMigration, $cheminTest)) {
    if (Test-Path -LiteralPath $chemin) { [Console]::Error.WriteLine("Le fichier existe déjà : $chemin"); exit 1 }
}

$modeleMigration = @"
-- Migration : $nomMigration
-- Objet     : TODO décrire l'objet créé ou modifié et son but.
-- Billet    : TODO clé du billet (p. ex. ATL-3)

-- TODO : écrire le DDL (schéma explicite, contraintes nommées, voir .github/instructions/sql.instructions.md).
"@

$modeleTest = @"
-- Test   : $nomTest
-- Objet  : TODO décrire l'attente vérifiée par ce test.
-- Billet : TODO clé du billet
-- Les écritures sont annulées à la fin du test.

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- TODO : préparer les données, exécuter l'objet testé, puis vérifier chaque attente.
IF 1 = 0
    THROW 50900, N'TODO : remplacer par une attente réelle.', 1;

ROLLBACK TRANSACTION;

PRINT N'[OK] test_$Description';
"@

$encodage = [Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Path $dossierMigrations, $dossierTests -Force | Out-Null
[IO.File]::WriteAllText($cheminMigration, ($modeleMigration -replace "`r`n", "`n") + "`n", $encodage)
[IO.File]::WriteAllText($cheminTest, ($modeleTest -replace "`r`n", "`n") + "`n", $encodage)
Write-Output 'Fichiers créés. Remplissez les TODO, puis lancez : pwsh ./scripts/valider.ps1'
exit 0
