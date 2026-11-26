<#
.SYNOPSIS
    Hook preToolUse « garde-fous » : refuse de façon déterministe quelques actions dangereuses.

.DESCRIPTION
    Lit sur l'entrée standard le JSON envoyé par l'agent avant chaque appel d'outil et écrit
    une seule ligne JSON sur la sortie standard :
      - {"permissionDecision":"deny","permissionDecisionReason":"..."} pour :
          * toute lecture ou mention du fichier .env (pas .env.example) dans un chemin ou une commande;
          * flyway clean dans une commande;
          * DROP DATABASE dans une commande;
      - {} dans tous les autres cas, y compris une entrée illisible : le hook ne rend jamais « allow »,
        il laisse donc les autres règles et les confirmations habituelles s'appliquer.
    Formats d'entrée acceptés : GitHub Copilot CLI (toolName, toolArgs en chaîne JSON) et
    VS Code (tool_name, tool_input en objet).

    Un hook est un garde-fou, pas une frontière de sécurité. Le code de sortie est toujours 0.
    Compatible Windows PowerShell 5.1 et PowerShell 7.

.EXAMPLE
    '{"toolName":"bash","toolArgs":"{\"command\":\"cat .env\"}"}' | pwsh -NoProfile -File ./scripts/hooks/garde-fous.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$motifEnv = '(?<![\w.-])\.env(?![\w.-])'
$motifFlywayClean = '(?i)\bflyway\b[^\r\n|;&]*\bclean\b'
$motifDropDatabase = '(?i)\bDROP\s+DATABASE\b'
$motifCleChemin = '(?i)(path|file|uri|filename)'
$motifCleCommande = '(?i)^(command|cmd|commandline|script)$'

function Get-Valeurs {
    param($Noeud, [string]$Cle, [System.Collections.Generic.List[string]]$Chemins, [System.Collections.Generic.List[string]]$Commandes)
    if ($null -eq $Noeud) { return }
    if ($Noeud -is [string]) {
        if ($Cle -match $motifCleCommande) { $Commandes.Add($Noeud) }
        elseif ($Cle -match $motifCleChemin) { $Chemins.Add($Noeud) }
        return
    }
    if ($Noeud -is [System.Collections.IEnumerable] -and -not ($Noeud -is [System.Management.Automation.PSCustomObject])) {
        foreach ($element in $Noeud) { Get-Valeurs $element $Cle $Chemins $Commandes }
        return
    }
    if ($Noeud -is [System.Management.Automation.PSCustomObject]) {
        foreach ($propriete in $Noeud.PSObject.Properties) { Get-Valeurs $propriete.Value $propriete.Name $Chemins $Commandes }
    }
}

function Get-Decision {
    param([string]$Texte)
    if ([string]::IsNullOrWhiteSpace($Texte)) { return $null }
    $entree = $Texte | ConvertFrom-Json

    $arguments = $null
    foreach ($nom in @('toolArgs', 'tool_input')) {
        $propriete = $entree.PSObject.Properties[$nom]
        if ($propriete) { $arguments = $propriete.Value; break }
    }
    if ($null -eq $arguments) { return $null }

    $chemins = New-Object System.Collections.Generic.List[string]
    $commandes = New-Object System.Collections.Generic.List[string]
    if ($arguments -is [string]) {
        $objet = $null
        try { $objet = $arguments | ConvertFrom-Json } catch { $objet = $null }
        if ($null -ne $objet -and -not ($objet -is [string])) { Get-Valeurs $objet '' $chemins $commandes }
        # Arguments non JSON : seule la règle .env s'applique, pour éviter les faux positifs.
        elseif ($arguments -match $motifEnv) { return 'Lecture du fichier .env refusée par le hook garde-fous : il contient des secrets. Les scripts des skills le lisent eux-mêmes.' }
    }
    else { Get-Valeurs $arguments '' $chemins $commandes }

    foreach ($valeur in @($chemins) + @($commandes)) {
        if ($valeur -match $motifEnv) { return 'Accès au fichier .env refusé par le hook garde-fous : il contient des secrets. Les scripts des skills le lisent eux-mêmes; utilisez .env.example comme modèle.' }
    }
    foreach ($commande in $commandes) {
        if ($commande -match $motifFlywayClean) { return 'flyway clean refusé par le hook garde-fous : cette commande supprime tous les objets du schéma. Utilisez une base jetable (scripts/valider.ps1).' }
        if ($commande -match $motifDropDatabase) { return 'DROP DATABASE refusé par le hook garde-fous : la suppression de base se fait seulement par scripts/valider.ps1 sur sa base jetable.' }
    }
    return $null
}

$sortie = '{}'
try {
    $texte = [Console]::In.ReadToEnd()
    $raison = Get-Decision $texte
    if ($raison) {
        $sortie = [ordered]@{ permissionDecision = 'deny'; permissionDecisionReason = $raison } | ConvertTo-Json -Compress
    }
}
catch {
    [Console]::Error.WriteLine("garde-fous : entrée ignorée ($($_.Exception.Message))")
    $sortie = '{}'
}
[Console]::Out.WriteLine($sortie)
exit 0
