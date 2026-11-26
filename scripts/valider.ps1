<#
.SYNOPSIS
    Script de validation unique du dépôt, identique en local et en CI.

.DESCRIPTION
    Étapes, dans l'ordre :
      1. Lint SQL avec sqlfluff (dialecte tsql, templater raw).
      2. Vérification des personnalisations GitHub Copilot (skills, agents, hooks).
      3. Tests du hook de garde-fous (fixtures de tests/hooks).
      4. Tests des scripts de skills en -Simulation (tests/skills).
      5. flyway migrate sur une base jetable.
      6. Tests SQL (tests/sql/test_*.sql) avec sqlcmd, en arrêt sur erreur.

    Modes :
      Docker        (défaut, utilisé en CI) : conteneur SQL Server jetable, supprimé à la fin.
      Local         : instance SQL Server existante (paramètres dans .env), base jetable supprimée à la fin.
      LintSeulement : étapes 1 à 4 seulement, pour les postes ou agents sans Docker ni SQL Server.

    Un outil absent est signalé [IGNORE] sur un poste, mais [ECHEC] en CI
    (variables CI ou TF_BUILD présentes). Code de sortie 0 seulement si aucune étape n'est en échec.

    Compatible Windows PowerShell 5.1 et PowerShell 7 (Windows et Linux).

.EXAMPLE
    pwsh ./scripts/valider.ps1
.EXAMPLE
    pwsh ./scripts/valider.ps1 -Mode LintSeulement
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\valider.ps1 -Mode Local
#>
[CmdletBinding()]
param(
    [ValidateSet('Docker', 'Local', 'LintSeulement')]
    [string]$Mode = 'Docker',

    # Image SQL Server utilisée en mode Docker (édition Developer).
    [string]$ImageSqlServer = 'mcr.microsoft.com/mssql/server:2022-latest',

    # Image Flyway utilisée en mode Docker si la CLI Flyway n'est pas installée.
    [string]$ImageFlyway = 'redgate/flyway:13',

    # Délai maximal d'attente du démarrage de SQL Server, en secondes.
    [int]$DelaiAttenteSec = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$racine = Split-Path -Parent $PSScriptRoot
$enCI = -not [string]::IsNullOrEmpty($env:CI) -or -not [string]::IsNullOrEmpty($env:TF_BUILD)
$moteurPowerShell = (Get-Process -Id $PID).Path
$resultats = New-Object System.Collections.Generic.List[object]
$identifiant = [guid]::NewGuid().ToString('N').Substring(0, 8)
$nomBase = "brulerie_val_$identifiant"

try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { Write-Verbose 'Encodage console inchangé.' }

#region Fonctions utilitaires

function Add-Resultat {
    param([string]$Etape, [ValidateSet('OK', 'ECHEC', 'IGNORE')][string]$Statut, [string]$Detail = '')
    $resultats.Add([pscustomobject]@{ Etape = $Etape; Statut = $Statut; Detail = $Detail })
    $couleur = @{ OK = 'Green'; ECHEC = 'Red'; IGNORE = 'Yellow' }[$Statut]
    Write-Host ("[{0}] {1} {2}" -f $Statut, $Etape, $Detail) -ForegroundColor $couleur
}

# Outil absent : [IGNORE] sur un poste, [ECHEC] en CI.
function Add-OutilAbsent {
    param([string]$Etape, [string]$Raison)
    if ($enCI) { Add-Resultat $Etape 'ECHEC' "$Raison (obligatoire en CI)" }
    else { Add-Resultat $Etape 'IGNORE' $Raison }
}

function Test-Commande {
    param([string]$Nom)
    return [bool](Get-Command $Nom -CommandType Application -ErrorAction SilentlyContinue)
}

# Exécute une commande externe sans que stderr ne devienne une erreur terminante (Windows PowerShell 5.1).
function Invoke-Externe {
    param([string]$Executable, [string[]]$Arguments, [switch]$Silencieux)
    $preferencePrecedente = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $sortie = & $Executable @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $preferencePrecedente }
    if (-not $Silencieux -and $sortie) { $sortie | ForEach-Object { Write-Host "    $_" } }
    return [pscustomobject]@{ Code = $code; Sortie = @($sortie) }
}

function Write-Titre {
    param([string]$Texte)
    Write-Host ''
    Write-Host "=== $Texte ===" -ForegroundColor Cyan
}

# Lit l'en-tête YAML (frontmatter) d'un fichier Markdown : clés de premier niveau seulement.
function Read-EnTete {
    param([string]$Chemin)
    $lignes = [IO.File]::ReadAllLines($Chemin, [Text.Encoding]::UTF8)
    if ($lignes.Count -lt 2 -or $lignes[0].Trim() -ne '---') { return $null }
    $enTete = [ordered]@{}
    $cle = $null
    for ($i = 1; $i -lt $lignes.Count; $i++) {
        $ligne = $lignes[$i]
        if ($ligne.Trim() -eq '---') { return $enTete }
        if ($ligne -match '^([A-Za-z0-9_-]+)\s*:\s*(.*)$') {
            $cle = $Matches[1]
            $valeur = $Matches[2].Trim()
            if ($valeur -in @('>', '|', '>-', '|-')) { $valeur = '' }
            $enTete[$cle] = $valeur.Trim('"', "'")
        }
        elseif ($cle -and $ligne -match '^\s+(.+)$') {
            $enTete[$cle] = ($enTete[$cle] + ' ' + $Matches[1].Trim()).Trim()
        }
    }
    return $null
}

# Lit .env (CLE=valeur) sans écraser les variables déjà définies dans l'environnement.
function Import-FichierEnv {
    param([string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) { return }
    foreach ($ligne in [IO.File]::ReadAllLines($Chemin, [Text.Encoding]::UTF8)) {
        if ($ligne -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $nom = $Matches[1]
            $valeur = $Matches[2].Trim().Trim('"', "'")
            if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($nom)) -and $valeur) {
                [Environment]::SetEnvironmentVariable($nom, $valeur)
            }
        }
    }
}

# Lance un script PowerShell enfant avec le même moteur, en passant une entrée sur stdin.
function Invoke-ScriptEnfant {
    param([string]$Script, [string[]]$Arguments = @(), [string]$Entree = $null)
    $infos = New-Object System.Diagnostics.ProcessStartInfo
    $infos.FileName = $moteurPowerShell
    $tous = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $Script) + $Arguments
    $infos.Arguments = ($tous | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $infos.UseShellExecute = $false
    $infos.RedirectStandardInput = $true
    $infos.RedirectStandardOutput = $true
    $infos.RedirectStandardError = $true
    $infos.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $infos.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $infos.WorkingDirectory = $racine
    $processus = [Diagnostics.Process]::Start($infos)
    if ($null -ne $Entree) {
        $octets = [Text.UTF8Encoding]::new($false).GetBytes($Entree)
        $processus.StandardInput.BaseStream.Write($octets, 0, $octets.Length)
    }
    $processus.StandardInput.Close()
    $lectureErreur = $processus.StandardError.ReadToEndAsync()
    $sortie = $processus.StandardOutput.ReadToEnd()
    $processus.WaitForExit()
    return [pscustomobject]@{ Code = $processus.ExitCode; Sortie = $sortie; Erreur = $lectureErreur.Result }
}

#endregion

#region Étape 1 : lint SQL

function Invoke-EtapeLint {
    $etape = '1. Lint SQL (sqlfluff)'
    Write-Titre $etape
    $commande = $null
    if (Test-Commande 'sqlfluff') { $commande = @('sqlfluff') }
    else {
        foreach ($python in @('python3', 'python')) {
            if ((Test-Commande $python) -and (Invoke-Externe $python @('-m', 'sqlfluff', '--version') -Silencieux).Code -eq 0) {
                $commande = @($python, '-m', 'sqlfluff'); break
            }
        }
    }
    if (-not $commande) {
        Add-OutilAbsent $etape 'sqlfluff absent : pip install -r requirements-dev.txt'
        return
    }
    $dossiers = @('migrations', 'donnees-exemple', 'tests/sql') | Where-Object { Test-Path (Join-Path $racine $_) }
    Push-Location $racine
    try {
        $arguments = @($commande | Select-Object -Skip 1) + @('lint') + $dossiers + @('--disable-progress-bar', '--nocolor')
        $resultat = Invoke-Externe $commande[0] $arguments
    }
    finally { Pop-Location }
    if ($resultat.Code -eq 0) { Add-Resultat $etape 'OK' ("{0} dossier(s) analysé(s)" -f $dossiers.Count) }
    else { Add-Resultat $etape 'ECHEC' 'Violations sqlfluff : corrigez-les ou lancez sqlfluff fix' }
}

#endregion

#region Étape 2 : personnalisations GitHub Copilot

function Invoke-EtapePersonnalisations {
    $etape = '2. Personnalisations GitHub Copilot'
    Write-Titre $etape
    $erreurs = New-Object System.Collections.Generic.List[string]
    $nbSkills = 0; $nbAgents = 0; $nbHooks = 0

    $dossierSkills = Join-Path $racine '.github/skills'
    if (Test-Path $dossierSkills) {
        foreach ($dossier in Get-ChildItem -LiteralPath $dossierSkills -Directory) {
            $fichier = Join-Path $dossier.FullName 'SKILL.md'
            if (-not (Test-Path -LiteralPath $fichier)) { $erreurs.Add("Skill $($dossier.Name) : SKILL.md absent"); continue }
            $nbSkills++
            $enTete = Read-EnTete $fichier
            if (-not $enTete) { $erreurs.Add("Skill $($dossier.Name) : en-tête YAML absent ou non fermé"); continue }
            $nom = if ($enTete.Contains('name')) { $enTete['name'] } else { '' }
            if ($nom -cne $dossier.Name) { $erreurs.Add("Skill $($dossier.Name) : name ('$nom') doit être identique au dossier") }
            if ($nom -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $erreurs.Add("Skill $($dossier.Name) : name en minuscules et traits d'union seulement") }
            if (-not $enTete.Contains('description') -or [string]::IsNullOrWhiteSpace($enTete['description'])) {
                $erreurs.Add("Skill $($dossier.Name) : description requise")
            }
            if ($enTete.Contains('allowed-tools') -and $enTete['allowed-tools'] -match '(?i)\b(shell|bash|powershell)\b') {
                $erreurs.Add("Skill $($dossier.Name) : ni shell ni bash dans allowed-tools")
            }
        }
    }

    $dossierAgents = Join-Path $racine '.github/agents'
    if (Test-Path $dossierAgents) {
        foreach ($fichier in Get-ChildItem -LiteralPath $dossierAgents -Filter '*.agent.md' -File) {
            $nbAgents++
            $enTete = Read-EnTete $fichier.FullName
            if (-not $enTete -or -not $enTete.Contains('description') -or [string]::IsNullOrWhiteSpace($enTete['description'])) {
                $erreurs.Add("Agent $($fichier.Name) : description requise dans l'en-tête YAML")
            }
        }
    }

    $dossierHooks = Join-Path $racine '.github/hooks'
    if (Test-Path $dossierHooks) {
        $fichiersHooks = Get-ChildItem -LiteralPath $dossierHooks -File | Where-Object { $_.Name -like '*.json' -or $_.Name -like '*.json.disabled' }
        foreach ($fichier in $fichiersHooks) {
            $nbHooks++
            try {
                $json = [IO.File]::ReadAllText($fichier.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
                if (-not ($json.PSObject.Properties.Name -contains 'version') -or $json.version -ne 1) { $erreurs.Add("Hook $($fichier.Name) : version: 1 requise") }
                if (-not ($json.PSObject.Properties.Name -contains 'hooks')) { $erreurs.Add("Hook $($fichier.Name) : objet hooks requis") }
            }
            catch { $erreurs.Add("Hook $($fichier.Name) : JSON invalide") }
        }
    }

    $prompts = Get-ChildItem -LiteralPath $racine -Recurse -File -Filter '*.prompt.md' -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    foreach ($fichier in $prompts) { $erreurs.Add("Fichier de prompt non pris en charge : $($fichier.Name) (utilisez un skill)") }

    $erreurs | ForEach-Object { Write-Host "    $_" }
    $detail = "$nbSkills skill(s), $nbAgents agent(s), $nbHooks hook(s)"
    if ($erreurs.Count -eq 0) { Add-Resultat $etape 'OK' $detail }
    else { Add-Resultat $etape 'ECHEC' "$($erreurs.Count) problème(s); $detail" }
}

#endregion

#region Étape 3 : tests du hook

function Invoke-EtapeHook {
    $etape = '3. Tests du hook (fixtures)'
    Write-Titre $etape
    $dossierFixtures = Join-Path $racine 'tests/hooks'
    $fixtures = @(Get-ChildItem -LiteralPath $dossierFixtures -Filter '*.json' -File -ErrorAction SilentlyContinue)
    if ($fixtures.Count -eq 0) { Add-Resultat $etape 'IGNORE' 'aucune fixture dans tests/hooks'; return }
    $scriptHook = Join-Path $racine 'scripts/hooks/garde-fous.ps1'
    if (-not (Test-Path -LiteralPath $scriptHook)) { Add-Resultat $etape 'ECHEC' 'scripts/hooks/garde-fous.ps1 absent'; return }

    $echecs = 0
    foreach ($fichier in $fixtures) {
        $cas = [IO.File]::ReadAllText($fichier.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $entree = if ($cas.PSObject.Properties.Name -contains 'entreeBrute') { [string]$cas.entreeBrute }
        else { $cas.entree | ConvertTo-Json -Depth 10 -Compress }
        $resultat = Invoke-ScriptEnfant -Script $scriptHook -Entree $entree
        $sortie = $resultat.Sortie.Trim()
        $probleme = $null
        if ($resultat.Code -ne 0) { $probleme = "code de sortie $($resultat.Code)" }
        else {
            try { $objet = $sortie | ConvertFrom-Json } catch { $objet = $null; $probleme = "sortie JSON invalide : $sortie" }
            if (-not $probleme) {
                $proprietes = @($objet.PSObject.Properties | ForEach-Object { $_.Name })
                $decision = if ($proprietes -contains 'permissionDecision') { $objet.permissionDecision } else { $null }
                if ($decision -eq 'allow') { $probleme = 'le hook ne doit jamais répondre allow' }
                elseif ($cas.attendu -eq 'refus') {
                    if ($decision -ne 'deny' -or [string]::IsNullOrWhiteSpace([string]$objet.permissionDecisionReason)) { $probleme = "refus attendu, obtenu : $sortie" }
                }
                elseif ($proprietes.Count -ne 0) { $probleme = "{} attendu, obtenu : $sortie" }
            }
        }
        if ($probleme) { $echecs++; Write-Host "    [ECHEC] $($fichier.BaseName) : $probleme" -ForegroundColor Red }
        else { Write-Host "    [OK] $($fichier.BaseName) : $($cas.description)" }
    }
    if ($echecs -eq 0) { Add-Resultat $etape 'OK' "$($fixtures.Count) fixture(s)" }
    else { Add-Resultat $etape 'ECHEC' "$echecs fixture(s) en échec sur $($fixtures.Count)" }
}

#endregion

#region Étape 4 : tests des scripts de skills

# Convention : chaque tests/skills/*.Tests.ps1 sort avec 0 (réussi), 2 (en attente) ou autre (échec).
function Invoke-EtapeSkills {
    $etape = '4. Scripts de skills (-Simulation)'
    Write-Titre $etape
    $tests = @(Get-ChildItem -LiteralPath (Join-Path $racine 'tests/skills') -Filter '*.Tests.ps1' -File -ErrorAction SilentlyContinue)
    if ($tests.Count -eq 0) { Add-Resultat $etape 'IGNORE' 'aucun test dans tests/skills'; return }
    foreach ($test in $tests) {
        $nom = $test.Name -replace '\.Tests\.ps1$', ''
        $resultat = Invoke-ScriptEnfant -Script $test.FullName
        ($resultat.Sortie + $resultat.Erreur).Split("`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    $($_.TrimEnd())" }
        switch ($resultat.Code) {
            0 { Add-Resultat "4. Skill $nom" 'OK' 'tests en simulation réussis' }
            2 { Add-Resultat "4. Skill $nom" 'IGNORE' 'tests en attente (script à compléter)' }
            default { Add-Resultat "4. Skill $nom" 'ECHEC' "code de sortie $($resultat.Code)" }
        }
    }
}

#endregion

#region Étapes 5 et 6 : Flyway et tests SQL

function Get-FichiersTestsSql {
    return @(Get-ChildItem -LiteralPath (Join-Path $racine 'tests/sql') -Filter 'test_*.sql' -File | Sort-Object Name)
}

function Invoke-FlywayMigrate {
    param([string]$Url, [string]$Utilisateur, [string]$MotDePasse, [string]$ReseauDocker)
    $env:FLYWAY_URL = $Url
    $env:SQL_UTILISATEUR = $Utilisateur
    $env:SQL_MOT_DE_PASSE = $MotDePasse
    $env:REDGATE_DISABLE_TELEMETRY = 'true'
    if (Test-Commande 'flyway') {
        Write-Host '    CLI Flyway locale'
        $arguments = @("-configFiles=$(Join-Path $racine 'flyway.toml')", "-workingDirectory=$racine", '-environment=ci', 'migrate')
        return (Invoke-Externe 'flyway' $arguments).Code
    }
    if ($ReseauDocker) {
        Write-Host "    Image $ImageFlyway"
        $arguments = @('run', '--rm', '--network', $ReseauDocker, '-v', "${racine}:/flyway/project:ro",
            '-e', 'FLYWAY_URL', '-e', 'SQL_UTILISATEUR', '-e', 'SQL_MOT_DE_PASSE', '-e', 'REDGATE_DISABLE_TELEMETRY',
            $ImageFlyway, '-configFiles=/flyway/project/flyway.toml', '-workingDirectory=/flyway/project', '-environment=ci', 'migrate')
        return (Invoke-Externe 'docker' $arguments).Code
    }
    return $null
}

function Clear-VariablesSecretes {
    foreach ($nom in @('FLYWAY_URL', 'SQL_MOT_DE_PASSE', 'SQLCMDPASSWORD', 'MSSQL_SA_PASSWORD')) {
        Remove-Item -Path "env:$nom" -ErrorAction SilentlyContinue
    }
}

function Invoke-ModeDocker {
    $etapeMigrate = '5. flyway migrate (Docker)'
    $etapeTests = '6. Tests SQL (Docker)'
    Write-Titre 'Mode Docker : SQL Server jetable'
    if (-not (Test-Commande 'docker')) {
        Add-OutilAbsent $etapeMigrate 'Docker absent : utilisez -Mode Local ou -Mode LintSeulement'
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        return
    }
    if ((Invoke-Externe 'docker' @('version', '--format', '{{.Server.Version}}') -Silencieux).Code -ne 0) {
        Add-OutilAbsent $etapeMigrate 'démon Docker inactif : démarrez Docker Desktop'
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        return
    }

    $reseau = "atelier-val-$identifiant"
    $conteneur = "atelier-sql-$identifiant"
    # Mot de passe généré pour ce conteneur seulement, jamais affiché.
    $motDePasse = 'Va1-' + [guid]::NewGuid().ToString('N').Substring(0, 20) + '!Z'
    $sqlcmd = $null
    try {
        $env:MSSQL_SA_PASSWORD = $motDePasse
        $env:SQLCMDPASSWORD = $motDePasse
        if ((Invoke-Externe 'docker' @('network', 'create', $reseau) -Silencieux).Code -ne 0) { throw 'création du réseau Docker impossible' }
        Write-Host "    Démarrage de $ImageSqlServer"
        $demarrage = Invoke-Externe 'docker' @('run', '-d', '--name', $conteneur, '--network', $reseau,
            '-e', 'ACCEPT_EULA=Y', '-e', 'MSSQL_PID=Developer', '-e', 'MSSQL_SA_PASSWORD', '-p', '127.0.0.1::1433', $ImageSqlServer)
        if ($demarrage.Code -ne 0) { throw "démarrage du conteneur SQL Server impossible (image $ImageSqlServer)" }

        $limite = (Get-Date).AddSeconds($DelaiAttenteSec)
        while (-not $sqlcmd -and (Get-Date) -lt $limite) {
            foreach ($candidat in @('/opt/mssql-tools18/bin/sqlcmd', '/opt/mssql-tools/bin/sqlcmd')) {
                $essai = Invoke-Externe 'docker' @('exec', '-e', 'SQLCMDPASSWORD', $conteneur, $candidat, '-S', 'localhost', '-U', 'sa', '-C', '-b', '-Q', 'SET NOCOUNT ON; SELECT 1') -Silencieux
                if ($essai.Code -eq 0) { $sqlcmd = $candidat; break }
            }
            if (-not $sqlcmd) { Start-Sleep -Seconds 3 }
        }
        if (-not $sqlcmd) { throw "SQL Server n'est pas prêt après $DelaiAttenteSec s" }
        Write-Host '    SQL Server prêt'

        $creation = Invoke-Externe 'docker' @('exec', '-e', 'SQLCMDPASSWORD', $conteneur, $sqlcmd, '-S', 'localhost', '-U', 'sa', '-C', '-b', '-Q', "CREATE DATABASE [$nomBase]")
        if ($creation.Code -ne 0) { throw 'création de la base jetable impossible' }

        $port = $null
        $publication = Invoke-Externe 'docker' @('port', $conteneur, '1433/tcp') -Silencieux
        if ($publication.Code -eq 0 -and ($publication.Sortie -join "`n") -match ':(\d+)\s*$') { $port = $Matches[1] }
        if ((Test-Commande 'flyway') -and $port) {
            $url = "jdbc:sqlserver://127.0.0.1:${port};databaseName=$nomBase;encrypt=true;trustServerCertificate=true"
        }
        else {
            $url = "jdbc:sqlserver://${conteneur}:1433;databaseName=$nomBase;encrypt=true;trustServerCertificate=true"
        }
        $code = Invoke-FlywayMigrate -Url $url -Utilisateur 'sa' -MotDePasse $motDePasse -ReseauDocker $reseau
        if ($code -ne 0) {
            Add-Resultat $etapeMigrate 'ECHEC' 'flyway migrate a échoué'
            Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
            return
        }
        Add-Resultat $etapeMigrate 'OK' 'migrations et données d''exemple appliquées'

        Write-Titre $etapeTests
        if ((Invoke-Externe 'docker' @('cp', (Join-Path $racine 'tests/sql'), "${conteneur}:/tmp/tests-sql") -Silencieux).Code -ne 0) { throw 'copie des tests SQL impossible' }
        $echecs = 0; $fichiers = Get-FichiersTestsSql
        foreach ($fichier in $fichiers) {
            Write-Host "    $($fichier.Name)"
            $test = Invoke-Externe 'docker' @('exec', '-e', 'SQLCMDPASSWORD', $conteneur, $sqlcmd, '-S', 'localhost', '-U', 'sa', '-C', '-b', '-I', '-f', '65001', '-d', $nomBase, '-i', "/tmp/tests-sql/$($fichier.Name)")
            if ($test.Code -ne 0) { $echecs++ }
        }
        if ($echecs -eq 0) { Add-Resultat $etapeTests 'OK' "$($fichiers.Count) test(s)" }
        else { Add-Resultat $etapeTests 'ECHEC' "$echecs test(s) en échec sur $($fichiers.Count)" }
    }
    catch {
        if (-not ($resultats | Where-Object { $_.Etape -eq $etapeMigrate })) {
            Add-Resultat $etapeMigrate 'ECHEC' $_.Exception.Message
            Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        }
        else { Add-Resultat $etapeTests 'ECHEC' $_.Exception.Message }
    }
    finally {
        Write-Host '    Nettoyage du conteneur et du réseau'
        Invoke-Externe 'docker' @('rm', '-f', '-v', $conteneur) -Silencieux | Out-Null
        Invoke-Externe 'docker' @('network', 'rm', $reseau) -Silencieux | Out-Null
        Clear-VariablesSecretes
    }
}

# Convertit SQL_SERVEUR (hôte, hôte,port, hôte\instance) en URL JDBC.
function ConvertTo-UrlJdbc {
    param([string]$Serveur, [string]$Base, [bool]$Integree)
    $hote = $Serveur; $port = $null; $instance = $null
    if ($hote -match '^(.*),(\d+)$') { $hote = $Matches[1]; $port = $Matches[2] }
    if ($hote -match '^(.*)\\(.+)$') { $hote = $Matches[1]; $instance = $Matches[2] }
    if ($hote -in @('.', '(local)', '')) { $hote = 'localhost' }
    $url = "jdbc:sqlserver://$hote"
    if ($port) { $url += ":$port" }
    $url += ";databaseName=$Base;encrypt=true;trustServerCertificate=true"
    if ($instance -and -not $port) { $url += ";instanceName=$instance" }
    if ($Integree) { $url += ';integratedSecurity=true' }
    return $url
}

function Invoke-ModeLocal {
    $etapeMigrate = '5. flyway migrate (Local)'
    $etapeTests = '6. Tests SQL (Local)'
    Write-Titre 'Mode Local : base jetable sur une instance existante'
    Import-FichierEnv (Join-Path $racine '.env')
    $serveur = $env:SQL_SERVEUR
    if ([string]::IsNullOrWhiteSpace($serveur)) {
        Add-Resultat $etapeMigrate 'ECHEC' 'SQL_SERVEUR manquant : copiez .env.example en .env et remplissez-le'
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        return
    }
    $authentification = if ($env:SQL_AUTHENTIFICATION) { $env:SQL_AUTHENTIFICATION.ToLowerInvariant() } elseif ($env:SQL_UTILISATEUR) { 'sql' } else { 'windows' }
    if ($authentification -notin @('windows', 'sql')) {
        Add-Resultat $etapeMigrate 'ECHEC' "SQL_AUTHENTIFICATION doit valoir windows ou sql (valeur : $authentification)"
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        return
    }
    $integree = $authentification -eq 'windows'
    if (-not (Test-Commande 'sqlcmd')) {
        Add-OutilAbsent $etapeMigrate 'sqlcmd absent (requis en mode Local)'
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        return
    }
    if (-not (Test-Commande 'flyway')) {
        Add-OutilAbsent $etapeMigrate 'CLI Flyway absente (requise en mode Local)'
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
        return
    }

    $connexion = @('-S', $serveur, '-C', '-b')
    if ($integree) { $connexion += '-E' }
    else {
        $connexion += @('-U', $env:SQL_UTILISATEUR)
        $env:SQLCMDPASSWORD = $env:SQL_MOT_DE_PASSE
    }
    $baseCreee = $false
    try {
        $creation = Invoke-Externe 'sqlcmd' ($connexion + @('-Q', "CREATE DATABASE [$nomBase]"))
        if ($creation.Code -ne 0) { throw "création de la base jetable impossible sur $serveur" }
        $baseCreee = $true
        Write-Host "    Base jetable : $nomBase"

        $url = ConvertTo-UrlJdbc -Serveur $serveur -Base $nomBase -Integree $integree
        # Authentification intégrée : le pilote ignore l'utilisateur, mais le résolveur ${env.*} exige une valeur.
        $utilisateur = if ($integree) { 'authentification-integree' } else { $env:SQL_UTILISATEUR }
        $motDePasse = if ($integree) { 'authentification-integree' } else { $env:SQL_MOT_DE_PASSE }
        $code = Invoke-FlywayMigrate -Url $url -Utilisateur $utilisateur -MotDePasse $motDePasse
        if ($code -ne 0) {
            Add-Resultat $etapeMigrate 'ECHEC' 'flyway migrate a échoué (TCP/IP activé sur l''instance? voir le dépannage du README)'
            Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
            return
        }
        Add-Resultat $etapeMigrate 'OK' 'migrations et données d''exemple appliquées'

        Write-Titre $etapeTests
        $echecs = 0; $fichiers = Get-FichiersTestsSql
        foreach ($fichier in $fichiers) {
            Write-Host "    $($fichier.Name)"
            $test = Invoke-Externe 'sqlcmd' ($connexion + @('-I', '-f', '65001', '-d', $nomBase, '-i', $fichier.FullName))
            if ($test.Code -ne 0) { $echecs++ }
        }
        if ($echecs -eq 0) { Add-Resultat $etapeTests 'OK' "$($fichiers.Count) test(s)" }
        else { Add-Resultat $etapeTests 'ECHEC' "$echecs test(s) en échec sur $($fichiers.Count)" }
    }
    catch {
        Add-Resultat $etapeMigrate 'ECHEC' $_.Exception.Message
        Add-Resultat $etapeTests 'IGNORE' "dépend de l'étape 5"
    }
    finally {
        if ($baseCreee) {
            Write-Host "    Suppression de $nomBase"
            Invoke-Externe 'sqlcmd' ($connexion + @('-d', 'master', '-Q', "ALTER DATABASE [$nomBase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$nomBase];")) -Silencieux | Out-Null
        }
        Clear-VariablesSecretes
    }
}

#endregion

Write-Host "Validation du dépôt - mode $Mode$(if ($enCI) { ' (CI)' })"

Invoke-EtapeLint
Invoke-EtapePersonnalisations
Invoke-EtapeHook
Invoke-EtapeSkills
switch ($Mode) {
    'Docker' { Invoke-ModeDocker }
    'Local' { Invoke-ModeLocal }
    'LintSeulement' {
        Add-Resultat '5. flyway migrate' 'IGNORE' 'mode LintSeulement'
        Add-Resultat '6. Tests SQL' 'IGNORE' 'mode LintSeulement'
    }
}

Write-Titre 'Récapitulatif'
$largeur = ($resultats | ForEach-Object { $_.Etape.Length } | Measure-Object -Maximum).Maximum
foreach ($r in $resultats) {
    $couleur = @{ OK = 'Green'; ECHEC = 'Red'; IGNORE = 'Yellow' }[$r.Statut]
    Write-Host ("{0,-8} {1} {2}" -f "[$($r.Statut)]", $r.Etape.PadRight($largeur), $r.Detail) -ForegroundColor $couleur
}
$nbEchecs = @($resultats | Where-Object { $_.Statut -eq 'ECHEC' }).Count
if ($nbEchecs -gt 0) {
    Write-Host "Validation en échec : $nbEchecs étape(s)." -ForegroundColor Red
    exit 1
}
Write-Host 'Validation réussie.' -ForegroundColor Green
exit 0
