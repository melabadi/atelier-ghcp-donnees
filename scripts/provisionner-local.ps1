<#
.SYNOPSIS
    Crée une base de démo persistante sur une instance LOCALE.
.DESCRIPTION
    Refuse toute base existante sans marque de propriété. Ne supprime aucune base.
    Ne charge pas dw.vente automatiquement (ATL-2 : relance non idempotente sur main).
#>
[CmdletBinding()]
param(
    [ValidatePattern('^brulerie_demo(?:_[a-z0-9_]+)?$')]
    [string]$Base = 'brulerie_demo',
    [string]$Serveur,
    [ValidateSet('Flyway', 'SqlcmdInitial')]
    [string]$MethodeSchema = 'Flyway'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$racine = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'sql-server.ps1')
Import-FichierEnv (Join-Path $racine '.env')
if (-not $Serveur) { $Serveur = $env:SQL_SERVEUR }
if (-not $Serveur -or $Serveur -notmatch '^(?:\.|\(local\)|localhost|127\.0\.0\.1)(?:\\[A-Za-z0-9_-]+|,\d+)?$') {
    throw 'Serveur local requis : localhost,port ou .\SQLEXPRESS; aucun hôte distant accepté.'
}
foreach ($outil in @('sqlcmd')) {
    if (-not (Test-Commande $outil)) { throw "Outil requis absent : $outil" }
}
if ($MethodeSchema -eq 'Flyway' -and -not (Test-Commande 'flyway')) { throw 'Outil requis absent : flyway' }
$auth = if ($env:SQL_AUTHENTIFICATION) { $env:SQL_AUTHENTIFICATION.ToLowerInvariant() } elseif ($env:SQL_UTILISATEUR) { 'sql' } else { 'windows' }
if ($auth -notin @('windows', 'sql')) { throw 'SQL_AUTHENTIFICATION doit valoir windows ou sql.' }
$connexion = @('-S', $Serveur, '-C', '-b', '-l', '15')
if ($auth -eq 'windows') { $connexion += '-E' }
else {
    if (-not $env:SQL_UTILISATEUR -or -not $env:SQL_MOT_DE_PASSE) { throw 'Identifiants SQL manquants.' }
    $connexion += @('-U', $env:SQL_UTILISATEUR)
    $env:SQLCMDPASSWORD = $env:SQL_MOT_DE_PASSE
}
try {
    if ($MethodeSchema -eq 'Flyway') {
        # Vérifie TCP avant toute création : la mémoire partagée ne suffit pas pour JDBC.
        $serveurTcp = $Serveur -replace '^(?:\.|\(local\))(?=\\|,|$)', 'localhost'
        $sonde = Invoke-Externe 'sqlcmd' (@('-S', "tcp:$serveurTcp") + @($connexion | Select-Object -Skip 2) +
            @('-d', 'master', '-Q', 'SET NOCOUNT ON; SELECT 1;'))
        if ($sonde.Code -ne 0) { throw "TCP SQL Server inaccessible : aucune base créée. Faire configurer TCP/port par l'administrateur; aucun service modifié." }
    }
    $proprietaire = "atelier-ghcp-donnees:$MethodeSchema"
    $empreinte = Get-EmpreinteSchemaInitial
    $creation = @"
SET NOCOUNT ON;
IF DB_ID(N'$Base') IS NULL
BEGIN
    CREATE DATABASE [$Base];
    EXEC [$Base].sys.sp_addextendedproperty @name=N'atelier_demo', @value=N'$proprietaire';
    SELECT N'NOUVELLE';
END
ELSE IF NOT EXISTS (
    SELECT 1 FROM [$Base].sys.extended_properties
    WHERE class = 0 AND name = N'atelier_demo' AND CONVERT(NVARCHAR(128), value) = N'$proprietaire'
)
    THROW 50300, N'Base existante non détenue par ce script : provisionnement refusé.', 1;
ELSE
    SELECT N'EXISTANTE';
"@
    $resultat = Invoke-Externe 'sqlcmd' ($connexion + @('-d', 'master', '-Q', $creation))
    if ($resultat.Code -ne 0) { throw 'Création/marque refusée; aucune base existante adoptée ou supprimée.' }
    if ($MethodeSchema -eq 'SqlcmdInitial') {
        if (($resultat.Sortie -join "`n") -match 'NOUVELLE') {
            Invoke-SchemaInitialSqlcmd -Connexion $connexion -Base $Base
            $marque = Invoke-Externe 'sqlcmd' ($connexion + @('-d', $Base, '-Q',
                "EXEC sys.sp_addextendedproperty @name=N'atelier_empreinte', @value=N'$empreinte';"))
            if ($marque.Code -ne 0) { throw "Empreinte non enregistrée; $Base conservée pour diagnostic." }
        }
        else {
            $verification = Invoke-Externe 'sqlcmd' ($connexion + @('-d', $Base, '-Q',
                "IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'atelier_empreinte' AND CONVERT(NVARCHAR(128), value) = N'$empreinte') THROW 50302, N'Instantané différent ou partiel : choisir un nouveau nom de base; aucune mise à niveau native.', 1;"))
            if ($verification.Code -ne 0) { throw 'Instantané différent ou partiel, relance refusée.' }
            Write-Host '    Instantané identique : aucune réapplication.'
        }
    }
    else {
        $integree = $auth -eq 'windows'
        $utilisateur = if ($integree) { 'authentification-integree' } else { $env:SQL_UTILISATEUR }
        $motDePasse = if ($integree) { 'authentification-integree' } else { $env:SQL_MOT_DE_PASSE }
        $code = Invoke-FlywayMigrate -Url (ConvertTo-UrlJdbc $Serveur $Base $integree) `
            -Utilisateur $utilisateur -MotDePasse $motDePasse -Environnement 'dev'
        if ($code -ne 0) { throw "Flyway a échoué; $Base conservée pour diagnostic, aucune suppression." }
    }
    Write-Host "[OK] Base persistante $Base sur $Serveur : schémas, procédure et données d'exemple prêts."
    Write-Host 'MSSQL/SSMS : sélectionner cette base; EXEC etl.usp_charger_ventes; pour un premier chargement.'
}
finally {
    foreach ($nom in @('FLYWAY_URL', 'SQLCMDPASSWORD', 'SQL_MOT_DE_PASSE')) {
        Remove-Item -Path "env:$nom" -ErrorAction SilentlyContinue
    }
}
