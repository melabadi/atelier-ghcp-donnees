# Fonctions communes de configuration et de migration; aucun nettoyage de base ici.
function Test-Commande {
    param([string]$Nom)
    return [bool](Get-Command $Nom -CommandType Application -ErrorAction SilentlyContinue)
}

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

function ConvertTo-UrlJdbc {
    param([string]$Serveur, [string]$Base, [bool]$Integree)
    $hote = $Serveur; $port = $null; $instance = $null
    if ($hote -match '^(.*),(\d+)$') { $hote = $Matches[1]; $port = $Matches[2] }
    if ($hote -match '^(.*)\\(.+)$') { $hote = $Matches[1]; $instance = $Matches[2] }
    if ($hote -in @('.', '(local)', '')) { $hote = 'localhost' }
    $url = "jdbc:sqlserver://$hote"
    if ($port) { $url += ":$port" }
    $url += ";databaseName=$Base;encrypt=true;trustServerCertificate=true;loginTimeout=15"
    if ($instance -and -not $port) { $url += ";instanceName=$instance" }
    if ($Integree) { $url += ';integratedSecurity=true' }
    return $url
}

function Invoke-FlywayMigrate {
    param(
        [string]$Url, [string]$Utilisateur, [string]$MotDePasse, [string]$ReseauDocker,
        [string]$Environnement = 'ci'
    )
    $env:FLYWAY_URL = $Url
    $env:SQL_UTILISATEUR = $Utilisateur
    $env:SQL_MOT_DE_PASSE = $MotDePasse
    $env:REDGATE_DISABLE_TELEMETRY = 'true'
    if (Test-Commande 'flyway') {
        Write-Host '    CLI Flyway locale'
        $arguments = @("-configFiles=$(Join-Path $racine 'flyway.toml')", "-workingDirectory=$racine",
            "-environment=$Environnement", 'migrate')
        return (Invoke-Externe 'flyway' $arguments).Code
    }
    if ($ReseauDocker) {
        Write-Host "    Image $ImageFlyway"
        $arguments = @('run', '--rm', '--network', $ReseauDocker, '-v', "${racine}:/flyway/project:ro",
            '-e', 'FLYWAY_URL', '-e', 'SQL_UTILISATEUR', '-e', 'SQL_MOT_DE_PASSE', '-e', 'REDGATE_DISABLE_TELEMETRY',
            $ImageFlyway, '-configFiles=/flyway/project/flyway.toml', '-workingDirectory=/flyway/project',
            "-environment=$Environnement", 'migrate')
        return (Invoke-Externe 'docker' $arguments).Code
    }
    throw 'Flyway absent : installez la CLI ou utilisez le mode Docker.'
}

function Get-FichiersSchemaInitial {
    $versions = @(Get-ChildItem (Join-Path $racine 'migrations') -Filter 'V*.sql' |
        Sort-Object { if ($_.Name -match '^V(\d+)__') { [int]$Matches[1] } else { throw "Nom invalide : $($_.Name)" } })
    $repetables = @(Get-ChildItem (Join-Path $racine 'migrations') -Filter 'R__*.sql' | Sort-Object Name)
    $donnees = @(Get-ChildItem (Join-Path $racine 'donnees-exemple') -Filter 'R__*.sql' | Sort-Object Name)
    return @($versions + $repetables + $donnees)
}

function Get-EmpreinteSchemaInitial {
    $texte = (Get-FichiersSchemaInitial | ForEach-Object {
        $_.Name + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($texte)))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Invoke-SchemaInitialSqlcmd {
    param([string[]]$Connexion, [string]$Base)
    # Un instantané initial, pas un moteur de migration : jamais sur une base avec des tables.
    $sonde = Invoke-Externe 'sqlcmd' ($Connexion + @('-d', $Base, '-Q',
        "IF EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped = 0) THROW 50301, N'Initialisation exige une base neuve sans tables.', 1;"))
    if ($sonde.Code -ne 0) { throw 'Initialisation refusée : base non vide.' }
    foreach ($fichier in Get-FichiersSchemaInitial) {
        Write-Host "    Initialisation : $($fichier.Name)"
        $resultat = Invoke-Externe 'sqlcmd' ($Connexion + @('-d', $Base, '-I', '-f', '65001', '-i', $fichier.FullName))
        if ($resultat.Code -ne 0) { throw "Initialisation partielle : $($fichier.Name) a échoué. Base conservée, aucune réussite simulée." }
    }
}
