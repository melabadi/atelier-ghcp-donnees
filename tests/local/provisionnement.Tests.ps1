<#
.SYNOPSIS
    Vérifie le provisionnement sans TCP sur une instance locale avec authentification Windows.
    Crée et nettoie uniquement deux bases dont les noms sont générés pour ce lancement.
#>
[CmdletBinding()]
param([string]$Serveur = '.\SQLEXPRESS')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Serveur -notmatch '^(?:\.|\(local\)|localhost|127\.0\.0\.1)(?:\\[A-Za-z0-9_-]+|,\d+)?$') {
    throw 'Instance locale requise.'
}
$racine = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $racine 'scripts/sql-server.ps1')
$script = Join-Path $racine 'scripts/provisionner-local.ps1'
$moteur = (Get-Process -Id $PID).Path
$env:SQL_AUTHENTIFICATION = 'windows'
$identifiant = [guid]::NewGuid().ToString('N')
$base = "brulerie_demo_test_$identifiant"
$nonDetenue = "brulerie_demo_refus_$identifiant"
$creees = New-Object System.Collections.Generic.List[string]
$connexion = @('-S', $Serveur, '-E', '-C', '-b', '-l', '15')
try {
    $r = Invoke-Externe 'sqlcmd' ($connexion + @('-d', 'master', '-Q',
        "IF DB_ID(N'$base') IS NOT NULL OR DB_ID(N'$nonDetenue') IS NOT NULL THROW 50303, N'Noms déjà utilisés : tests refusés.', 1;"))
    if ($r.Code -ne 0) { throw 'Précondition de base absente non respectée.' }
    $r = Invoke-Externe $moteur @('-NoProfile', '-File', $script, '-Serveur', $Serveur,
        '-Base', $base, '-MethodeSchema', 'SqlcmdInitial')
    if ($r.Code -ne 0) { throw 'Création sur base absente en échec.' }
    $creees.Add($base)
    $r = Invoke-Externe 'sqlcmd' ($connexion + @('-d', $base, '-Q',
        "IF (SELECT COUNT(*) FROM stg.vente_brute) <> 30 OR (SELECT COUNT(*) FROM dw.client) <> 8 OR OBJECT_ID(N'etl.usp_charger_ventes') IS NULL THROW 50304, N'Schéma ou données absents.', 1; DELETE FROM stg.vente_brute WHERE numero_vente = N'V-0001';"))
    if ($r.Code -ne 0) { throw 'Schéma ou données non vérifiés.' }
    $r = Invoke-Externe $moteur @('-NoProfile', '-File', $script, '-Serveur', $Serveur,
        '-Base', $base, '-MethodeSchema', 'SqlcmdInitial')
    if ($r.Code -ne 0) { throw 'Relance identique en échec.' }
    $r = Invoke-Externe 'sqlcmd' ($connexion + @('-d', $base, '-Q',
        "IF (SELECT COUNT(*) FROM stg.vente_brute) <> 29 THROW 50305, N'Relance a remplacé les données.', 1;"))
    if ($r.Code -ne 0) { throw 'Relance a modifié les données.' }
    $r = Invoke-Externe 'sqlcmd' ($connexion + @('-d', 'master', '-Q', "CREATE DATABASE [$nonDetenue];"))
    if ($r.Code -ne 0) { throw 'Base de refus non créée.' }
    $creees.Add($nonDetenue)
    $r = Invoke-Externe $moteur @('-NoProfile', '-File', $script, '-Serveur', $Serveur,
        '-Base', $nonDetenue, '-MethodeSchema', 'SqlcmdInitial') -Silencieux
    if ($r.Code -eq 0 -or ($r.Sortie -join "`n") -notmatch '50300') { throw 'Base non détenue non refusée comme attendu.' }
    $r = Invoke-Externe 'sqlcmd' ($connexion + @('-d', $nonDetenue, '-Q',
        "IF EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped = 0) OR EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0) THROW 50306, N'Base non détenue modifiée.', 1;"))
    if ($r.Code -ne 0) { throw 'Base non détenue modifiée.' }
    Write-Host '[OK] Création, données, relance sans écriture et refus de base non détenue.'
}
finally {
    foreach ($nom in $creees) {
        $r = Invoke-Externe 'sqlcmd' ($connexion + @('-d', 'master', '-Q',
            "IF DB_ID(N'$nom') IS NOT NULL BEGIN ALTER DATABASE [$nom] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$nom]; END;"))
        if ($r.Code -ne 0) { throw "Nettoyage en échec : $nom" }
    }
}
