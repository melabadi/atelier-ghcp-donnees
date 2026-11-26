# atelier-ghcp-donnees

Dépôt gabarit d'une journée « GitHub Copilot pour l'ingénierie de données », sur un petit projet SQL Server + Flyway fictif.

- **Objectif** : aller au-delà du clavardage avec GitHub Copilot (GHCP) et savoir quand utiliser le mode Plan, un skill, un agent personnalisé ou un hook.
- **Boucle visée** : billet → plan → migration SQL + test → demande de tirage (PR) → CI verte → commentaire dans le billet.
- **Format** : une démo le matin, puis un atelier pratique l'après-midi dans une copie de ce dépôt.

> Contenu communautaire non officiel : ce dépôt n'est publié ni par Microsoft ni par GitHub. Toutes les données sont fictives.

## Table des matières

1. [Prérequis](#prérequis)
2. [Obtenir une copie interne](#obtenir-une-copie-interne)
3. [Déroulé de la journée](#déroulé-de-la-journée)
4. [Étapes de l'atelier](#étapes-de-latelier)
5. [Quand utiliser quoi](#quand-utiliser-quoi)
6. [Structure du dépôt](#structure-du-dépôt)
7. [Validation et CI](#validation-et-ci)
8. [Hook de garde-fous](#hook-de-garde-fous)
9. [Dépannage](#dépannage)
10. [Réinitialiser pour une nouvelle cohorte](#réinitialiser-pour-une-nouvelle-cohorte)
11. [Sources](#sources)

## Prérequis

Cette section peut être transmise telle quelle à l'équipe qui prépare les postes.

### Poste participant

| Élément | Statut | Note |
| --- | --- | --- |
| VS Code récent + extension GitHub Copilot Chat | Requis | Copilot harness (le moteur qui coordonne modèle, contexte et outils des sessions d'agent GHCP, partagé avec GitHub Copilot CLI) par défaut depuis VS Code 1.143; le harness Local, déprécié, est retiré en février 2027 |
| Licence GitHub Copilot | Requis | Modèles offerts selon le plan et les politiques de l'organisation |
| Git | Requis | |
| PowerShell 7 | Recommandé | Nécessaire pour activer le hook sous Windows; les scripts restent compatibles avec Windows PowerShell 5.1 |
| Docker ou SQL Server local | Requis pour la validation complète | Sinon `-Mode LintSeulement`; pré-télécharger l'image SQL Server la veille |
| Flyway CLI Community ou image `redgate/flyway` | Requis pour la validation complète | Aucune licence |
| Python 3 + sqlfluff | Recommandé | Requis en CI (`pip install -r requirements-dev.txt`) |
| Python 3.10+ + pytest + pyodbc + Microsoft ODBC Driver 18 | Requis pour les tests Python réels | `python -m pip install -r requirements-dev.txt`; le pilote ODBC s'installe séparément. Pilote 17 existant : `PYTEST_ODBC_DRIVER=ODBC Driver 17 for SQL Server` |
| sqlcmd (go-sqlcmd) | Pour `-Mode Local` | |
| GitHub Copilot CLI | Optionnel | `winget install GitHub.Copilot`, `npm install -g @github/copilot` (Node.js 22+) ou catalogue interne; la politique GitHub Copilot CLI doit être activée dans l'organisation |
| GitHub CLI ou Azure CLI (extension azure-devops) | Optionnel | Créer la PR depuis le terminal |
| Accès à l'espace Jira de formation + jeton | Requis l'après-midi | Cloud : jeton d'API + courriel; Data Center : jeton d'accès personnel (PAT) |

Extensions VS Code recommandées (proposées à l'ouverture du dossier) : `GitHub.copilot-chat`, `ms-mssql.mssql`, `ms-vscode.powershell`.

### Animateur

Organisation et projet Azure DevOps de démo avec deux ou trois éléments de travail préparés; PAT avec la portée Work Items (lecture et écriture); compte GitHub personnel pour publier ou copier le gabarit.

### CI

GitHub Actions ou Azure Pipelines hébergé `ubuntu-24.04` (Docker, PowerShell 7 et Python inclus); les pipelines installent explicitement ODBC Driver 18 et les dépendances Python. Agent auto-hébergé sans Docker : `-Mode LintSeulement`.

### Vérifier un poste

Le script vérifie seulement : il n'installe rien.

```powershell
pwsh ./scripts/verifier-poste.ps1                  # mode Docker (par défaut)
pwsh ./scripts/verifier-poste.ps1 -Mode Local       # SQL Server local + Flyway CLI + sqlcmd
pwsh ./scripts/verifier-poste.ps1 -Mode LintSeulement
```

Chaque élément est marqué `[OK]`, `[MANQUANT]` (requis pour ce mode) ou `[OPTIONNEL]`, avec la marche à suivre.

## Obtenir une copie interne

Les participants n'ont pas besoin de compte GitHub externe : une personne récupère le gabarit par clonage anonyme (dépôt public) ou en ZIP, puis le pousse dans un dépôt interne vide (Azure Repos ou GitHub d'entreprise).

### Avec toutes les branches (recommandé)

`--mirror` conserve les branches de rattrapage `etape-1` à `etape-4`.

```powershell
git clone --mirror <URL publique du gabarit> atelier-ghcp-donnees.git
cd atelier-ghcp-donnees.git
git push --mirror <URL du dépôt interne vide>
```

Si le serveur cible refuse des références cachées (`refs/pull/*`), poussez seulement les branches et les étiquettes :

```powershell
git push <URL du dépôt interne vide> "refs/heads/*:refs/heads/*" "refs/tags/*:refs/tags/*"
```

### Par ZIP

Le ZIP ne contient que la branche affichée : téléchargez aussi celui de chaque branche `etape-*`, ou préférez le clonage ci-dessus.

### Vérifier la CI avant l'atelier

1. Dans la copie interne, configurez le pipeline (voir [Validation et CI](#validation-et-ci)).
2. Lancez-le sur `main`, puis sur chaque branche `etape-*` : tous doivent être verts.
3. Sur un poste préparé, lancez `pwsh ./scripts/verifier-poste.ps1`, puis `pwsh ./scripts/valider.ps1`.

## Déroulé de la journée

### Démo (matin)

| Heure | Segment | Ce qu'on montre dans le dépôt |
| --- | --- | --- |
| 9 h 30 – 9 h 40 | Pourquoi aller au-delà du clavardage | L'objectif de la journée |
| 9 h 40 – 9 h 50 | Surfaces et harness | VS Code (Copilot harness), GitHub Copilot CLI dans le même dépôt, SSMS pour l'exploration ponctuelle |
| 9 h 50 – 10 h 05 | Modes et modèles | Même demande en mode clavardage, Plan et Agent; choix du modèle selon le plan |
| 10 h 05 – 10 h 20 | Instructions | Même demande sans, puis avec `copilot-instructions.md` et `sql.instructions.md` |
| 10 h 20 – 10 h 35 | Skill explicite + agent personnalisé | `/nouvelle-migration`, puis revue par `relecteur-sql` (lecture seule) |
| 10 h 35 – 11 h 05 | Boucle complète avec Azure DevOps | Élément de travail → plan → migration + test → `valider.ps1` → PR → CI verte → commentaire dans l'élément de travail |
| 11 h 05 – 11 h 15 | Hook | Activation du hook, puis tentative de lecture de `.env` refusée de façon déterministe |
| 11 h 15 – 11 h 30 | Grille « quand utiliser quoi » + questions | [docs/quand-utiliser-quoi.md](docs/quand-utiliser-quoi.md) |

Dîner : 11 h 30 – 13 h. Déroulé minute par minute : [docs/animation/script-demo.md](docs/animation/script-demo.md).

### Atelier (après-midi)

| Heure | Étape | Résultat attendu | Rattrapage |
| --- | --- | --- | --- |
| 13 h 00 – 13 h 15 | Mise en place | Copie interne ouverte dans VS Code; `verifier-poste.ps1` et `valider.ps1` verts | — |
| 13 h 15 – 13 h 35 | Fichier d'instructions | Conventions de l'équipe ajoutées | `etape-1` |
| 13 h 35 – 14 h 05 | Jeton Jira + skill `jira-ticket` | Lecture d'un billet de l'espace de formation | `etape-2` |
| 14 h 05 – 15 h 05 | Boucle complète | Billet → plan → migration + test → PR → CI verte → commentaire Jira | `etape-3`, `etape-4` |
| 15 h 05 – 15 h 20 | Retour | Ce qui a marché, ce qu'on adopte dès lundi | — |
| 15 h 20 – 15 h 30 | Marge | — | — |

Guide des animateurs et des coachs : [docs/animation/guide-animateur.md](docs/animation/guide-animateur.md).

## Étapes de l'atelier

Règle commune : bloqué plus de 10 minutes sur une étape? Passez sur sa branche de rattrapage (`git switch etape-<n>`) et continuez.

### Étape 0 : mise en place

- **But** : un poste prêt et une validation verte avant de demander quoi que ce soit à GHCP.
- **Consignes** :
  1. Clonez la copie interne et ouvrez le dossier dans VS Code; acceptez les extensions recommandées.
  2. Dans la vue Chat, vérifiez que le Copilot harness (et non le harness Local) est choisi dans le sélecteur **Session Target**.
  3. Lancez `pwsh ./scripts/verifier-poste.ps1`, puis `pwsh ./scripts/valider.ps1` (ou `-Mode LintSeulement` sans Docker).
- **Exemple de demande** : « Explique la structure de ce dépôt et ce que fait scripts/valider.ps1, sans rien modifier. »
- **Résultat attendu** : récapitulatif de `valider.ps1` sans `[ECHEC]`.
- **Rattrapage** : aucun; demandez un coach.

### Étape 1 : fichier d'instructions

- **But** : que GHCP respecte les conventions de votre équipe sans que vous les répétiez à chaque demande.
- **Consignes** :
  1. Lisez `.github/copilot-instructions.md` et `.github/instructions/sql.instructions.md`.
  2. Ajoutez deux ou trois conventions de votre équipe (préfixes, en-têtes, règles de revue).
  3. Posez la même demande avant et après la modification, chaque fois dans une nouvelle session, et comparez.
- **Exemples de demandes** :
  - « Écris une vue qui liste les clients sans vente. » (avant, puis après)
  - « Quelles instructions du dépôt s'appliquent quand tu modifies un fichier .sql? »
- **Résultat attendu** : le SQL proposé suit les nouvelles conventions; `valider.ps1` reste vert.
- **Rattrapage** : `etape-1` (instructions avec un exemple de conventions d'équipe).

### Étape 2 : jeton Jira + skill jira-ticket

- **But** : lire un billet Jira depuis GHCP au moyen d'un skill, sans que le jeton entre dans la conversation.
- **Consignes** :
  1. Créez un jeton. Jira Cloud : jeton d'API de votre compte Atlassian. Jira Data Center : jeton d'accès personnel dans votre profil.
  2. Copiez `.env.example` en `.env` et remplissez `JIRA_URL`, `JIRA_DEPLOIEMENT` (`cloud` ou `datacenter`), `JIRA_COURRIEL` (Cloud seulement) et `JIRA_JETON`. Ne collez jamais le jeton dans le clavardage.
  3. Avec l'aide de GHCP, complétez les trois fonctions marquées `# TODO-ATELIER` dans `.github/skills/jira-ticket/jira-ticket.ps1`.
  4. Lancez `pwsh ./tests/skills/jira-ticket.Tests.ps1` : les tests passent de « en attente » à verts.
  5. Essayez d'abord sans réseau : `pwsh ./.github/skills/jira-ticket/jira-ticket.ps1 -Action Lire -Cle ATL-1 -Simulation`.
- **Exemples de demandes** :
  - « Complète les TODO-ATELIER de jira-ticket.ps1 en suivant leurs commentaires, puis lance ses tests. »
  - « Lis le billet ATL-1 et résume ses critères d'acceptation. »
- **Résultat attendu** : le billet de l'espace de formation s'affiche dans la conversation; `valider.ps1` reste vert.
- **Rattrapage** : `etape-2` (skill complet, tests activés). Plan B réseau : `-Simulation`, ou les billets Markdown de [docs/tickets/](docs/tickets/).

### Étape 3 : boucle complète

- **But** : enchaîner billet → plan → migration + test → PR → CI verte → commentaire Jira.
- **Consignes** :
  1. Choisissez un billet dans [docs/tickets/](docs/tickets/) : ATL-1 facile, ATL-2 à ATL-4 moyens, ATL-5 et ATL-6 en bonus.
  2. En mode Plan, demandez un plan à partir du billet; corrigez-le avant de l'accepter.
  3. En mode Agent, faites implémenter la migration et le test (skill `/nouvelle-migration` pour une migration versionnée).
  4. Demandez une revue à l'agent `relecteur-sql`, puis lancez `pwsh ./scripts/valider.ps1`.
  5. Créez une branche, poussez et ouvrez la PR tôt, avec la clé du billet dans le titre : la CI tourne pendant la revue.
  6. Une fois la CI verte, faites commenter le billet par le skill `jira-ticket`.
- **Exemples de demandes** :
  - « Lis le billet ATL-1 et propose un plan : fichiers à créer, tests, commandes de vérification. » (mode Plan)
  - « Implémente le plan. Utilise /nouvelle-migration si une migration versionnée est nécessaire. »
  - « Relis les fichiers modifiés de cette branche. » (agent `relecteur-sql`)
  - « Ajoute dans ATL-1 un commentaire qui résume la PR et le résultat de la CI. »
- **Résultat attendu** : PR ouverte, CI verte, commentaire visible dans le billet.
- **Rattrapage** : `etape-3` (ATL-1 réalisé), puis `etape-4` (ATL-2 corrigé, test de non-régression, exemple de description de PR, commentaire Jira simulé).

### Retour

Chaque table partage ce qui a marché, ce qui a bloqué et une pratique adoptée dès lundi.

## Quand utiliser quoi

La grille [docs/quand-utiliser-quoi.md](docs/quand-utiliser-quoi.md) croise chaque brique de GHCP (modes, instructions, skills, agent personnalisé, hook, MCP et connecteurs) avec son usage, un exemple tiré du dépôt et ce qu'elle n'est pas.

## Structure du dépôt

```text
.
├── .github/
│   ├── copilot-instructions.md           Instructions du dépôt (toujours chargées)
│   ├── instructions/sql.instructions.md  Instructions par chemin (fichiers .sql)
│   ├── agents/relecteur-sql.agent.md     Agent personnalisé de revue SQL, lecture seule
│   ├── skills/
│   │   ├── nouvelle-migration/           Skill explicite : prochaine migration + test
│   │   ├── azure-devops-workitem/        Skill : lire et commenter un élément de travail (démo)
│   │   └── jira-ticket/                  Skill : lire et commenter un billet Jira (atelier, à compléter)
│   ├── hooks/garde-fous.json.disabled    Hook preToolUse, livré désactivé
│   ├── workflows/validation.yml          CI GitHub Actions
│   └── pull_request_template.md          Gabarit de PR (GitHub)
├── .azuredevops/pull_request_template.md Gabarit de PR (Azure Repos)
├── azure-pipelines.yml                   CI Azure Pipelines (même script)
├── migrations/                           Migrations Flyway (V<n>__ versionnées, R__ répétables)
├── donnees-exemple/                      Données fictives (environnements dev et ci seulement)
├── tests/
│   ├── sql/                              Tests SQL (THROW si une attente échoue)
│   ├── python/                           pytest, contrats réels et mesures facultatives; SQL séparé
│   ├── local/                            Tests réels du provisionnement sans TCP
│   ├── hooks/                            Fixtures du hook
│   ├── skills/                           Tests des scripts de skills (-Simulation)
│   └── fixtures/                         Réponses d'API enregistrées
├── scripts/
│   ├── valider.ps1                       Validation unique, en local et en CI
│   ├── verifier-poste.ps1                Vérification d'un poste, sans installation
│   ├── provisionner-local.ps1            Base persistante locale pour MSSQL/SSMS
│   ├── sql-server.ps1                    Configuration partagée et initialisation du schéma
│   └── hooks/garde-fous.ps1              Script du hook
├── docs/
│   ├── quand-utiliser-quoi.md            Grille des briques GHCP
│   ├── tickets/                          Billets ATL-1 à ATL-6 + import-jira.csv
│   └── animation/                        Script de démo et guide d'animation
├── flyway.toml                           Configuration Flyway (environnements dev et ci)
├── .env.example                          Modèle de .env, sans valeur
└── .sqlfluff                             Règles de lint SQL (tsql)
```

Flux de données : `stg.vente_brute` (transit, texte brut) → `etl.usp_charger_ventes` → `dw.client`, `dw.produit`, `dw.vente`. Le schéma `rpt` accueille les vues de rapport.

## Validation et CI

### Le script unique

```powershell
pwsh ./scripts/valider.ps1                      # Docker : SQL Server jetable dans un conteneur
pwsh ./scripts/valider.ps1 -Mode Local          # instance existante, paramètres dans .env
pwsh ./scripts/valider.ps1 -Mode LintSeulement  # étapes 1 à 4, sans base de données
```

| Étape | Contenu |
| --- | --- |
| 1 | Lint SQL avec sqlfluff (dialecte tsql); paramètres ODBC des tests rendus uniquement pour le lint |
| 2 | Personnalisations GHCP : en-têtes des skills et des agents, JSON des hooks, aucun `*.prompt.md` |
| 3 | Tests du hook par fixtures (`tests/hooks/`) |
| 4 | Tests des scripts de skills en `-Simulation` (`tests/skills/`) |
| 5 | `flyway migrate` sur une base jetable |
| 6 | Tests SQL (`tests/sql/`) |
| 7 | Tests Python (`tests/python/`), sur la même base jetable réelle |

Le mot de passe SQL Server du conteneur est généré à chaque exécution et n'est jamais affiché. Un outil absent donne `[IGNORE]` sur un poste et `[ECHEC]` en CI. Le code de sortie vaut 1 dès qu'une étape échoue.

Paramètres : `-ImageSqlServer` (par défaut `mcr.microsoft.com/mssql/server:2022-latest`, à aligner sur la version de production), `-ImageFlyway` (par défaut `redgate/flyway:13`), `-DelaiAttenteSec` (par défaut 180).

En `-Mode Local`, remplissez `SQL_SERVEUR` dans `.env`. Si `SQL_AUTHENTIFICATION` reste vide, le script choisit `sql` quand `SQL_UTILISATEUR` est rempli, sinon `windows`. Flyway se connecte par TCP : l'instance doit accepter les connexions TCP.

### Tests Python sur SQL Server réel

Ces tests sont des **tests de comportement isolés de procédure**, pas des tests unitaires sans moteur : aucune réponse SQL n'est simulée. Le validateur crée une base `brulerie_val_<identifiant>`, applique le schéma et les données, puis lance `python -m pytest tests/python -q -s --tb=short --contrat-relance doublons`. Chaque test écrit dans une transaction annulée; la procédure peut elle-même annuler cette transaction lors d'une erreur. La base est supprimée à la fin, même après un échec. Une base de démo ou une base sans marque de propriété est refusée par pytest.

Cas vérifiés : conversions et montants exacts, résolution client/produit, paramètre `OUTPUT`, source vide, exclusions des lignes non convertibles/inconnues, propagation des erreurs de contrainte et annulation complète, contrat de relance.

```powershell
python -m pip install -r requirements-dev.txt
python -c "import pyodbc; print(pyodbc.drivers())"

# Poste SQL Express sans TCP : authentification Windows, pilote 17 déjà installé.
$env:SQL_SERVEUR = '.\SQLEXPRESS'
$env:SQL_AUTHENTIFICATION = 'windows'
$env:PYTEST_ODBC_DRIVER = 'ODBC Driver 17 for SQL Server'
pwsh .\scripts\verifier-poste.ps1 -Mode Local -MethodeSchema SqlcmdInitial
pwsh .\scripts\valider.ps1 -Mode Local -MethodeSchema SqlcmdInitial

# TCP configuré par l'administrateur : chemin Flyway habituel, recommandé pour les migrations.
pwsh .\scripts\valider.ps1 -Mode Local
```

`SqlcmdInitial` est une **initialisation seulement** : fichiers `V<n>` triés numériquement, objets `R__` par nom, puis données d'exemple. Aucun historique Flyway n'est créé. Il ne remplace pas Flyway pour mettre une base à niveau; il exige une base neuve sans tables et ne s'active jamais automatiquement après un échec JDBC. Aucun changement TCP, service SQL Server ou SQL Server Browser n'est effectué.

**Progression de l'atelier préservée** : sur `main` et jusqu'à `etape-3`, le deuxième appel insère encore les mêmes ventes (bogue ATL-2). Le contrat par défaut `doublons` vérifie ce comportement existant, sans le corriger. Après réalisation d'ATL-2 (ou après avoir reporté ces outils sur `etape-4`), utilisez `-ContratRelance idempotent`; cette option échoue volontairement sur `main` et exige zéro nouvelle insertion. Les outils ajoutés ne sont pas rétroportés automatiquement aux branches publiées. La vue mensuelle ATL-1 reste un sujet de `etape-3`; les tests Python ne l'exigent pas sur `main`.

### Latence et plan réel (facultatifs)

```powershell
# En reprenant les variables de connexion ci-dessus :
$env:PYTEST_LIGNES = '10000'             # 1 à 1000000
$env:PYTEST_REPETITIONS = '20'           # au moins 5; plus 2 échauffements
$env:PYTEST_RESULTATS = 'resultats-python'
pwsh .\scripts\valider.ps1 -Mode Local -MethodeSchema SqlcmdInitial -PerformancePython

# Budget explicite si l'équipe en a établi un sur cet environnement :
$env:PYTEST_P95_MAX_MS = '500'
pwsh .\scripts\valider.ps1 -Mode Local -MethodeSchema SqlcmdInitial -PerformancePython
```

Sans `PYTEST_P95_MAX_MS`, le scénario **mesure** sans verdict de latence. Avec un budget positif et fini, pytest échoue si le p95 le dépasse. Chaque répétition recharge une cible vide; remise à zéro, génération des données et capture du plan sont exclues du chronométrage. Le temps client comprend l'appel ODBC et la réception du paramètre de sortie; le cache est réchauffé, la connexion est réutilisée et une transaction externe est annulée. Ce n'est donc ni une mesure de connexion, ni une mesure de validation durable du journal, ni une preuve de débit de production.

Chaque lancement conserve un dossier unique : `mesures.json` (échantillons, médiane, p95 par rang, version du moteur, volume, budget) et `chargement-*.sqlplan` ouvrables dans SSMS. L'analyse descriptive liste les opérateurs, lignes estimées, lignes réelles cumulées par thread, exécutions, avertissements et suggestions d'index. Les estimations sont par exécution : comparez-les aux lignes réelles en tenant compte du nombre d'exécutions. Aucun `Index Seek` n'est imposé; un scan peut être raisonnable selon les données. Les suggestions du moteur ne sont pas appliquées automatiquement.

**Fait documenté** : `SET STATISTICS XML ON` exécute réellement la requête et retourne le plan avec ses compteurs; les permissions d'exécution et `SHOWPLAN` sont nécessaires sur les bases référencées ([Microsoft Learn](https://learn.microsoft.com/sql/t-sql/statements/set-statistics-xml-transact-sql?view=sql-server-ver17)). **Recommandation de l'atelier** : ajuster volume, distribution, concurrence et budget sur un environnement représentatif avant toute conclusion de performance. Aucun cache global ni réglage de l'instance n'est modifié.

### Provisionner une base locale pour MSSQL/SSMS

```powershell
# Sans TCP, sur le poste SQL Express décrit ci-dessus :
pwsh .\scripts\provisionner-local.ps1 -Serveur '.\SQLEXPRESS' -Base brulerie_demo_python -MethodeSchema SqlcmdInitial

# Avec TCP : Flyway dev, schéma et données d'exemple idempotentes.
pwsh .\scripts\provisionner-local.ps1 -Serveur 'localhost,1433' -Base brulerie_demo

# Tests réels de sécurité du provisionnement; deux bases uniques nettoyées à la fin.
pwsh .\tests\local\provisionnement.Tests.ps1 -Serveur '.\SQLEXPRESS'
```

Le nom doit commencer par `brulerie_demo`; seuls `.`, `(local)`, `localhost` et `127.0.0.1`, avec instance ou port facultatif, sont acceptés. Le compte doit pouvoir créer une base et ses objets. Les identifiants peuvent venir des variables `SQL_*` ou de `.env` lu par le script, jamais affiché. Ne copiez pas de secret dans une commande; `.env` reste ignoré par Git. La confiance au certificat est réservée à ces environnements locaux de démo.

Une base préexistante non marquée est refusée, jamais adoptée, vidée ou supprimée. Les marques distinguent `Flyway` et `SqlcmdInitial` : impossible de passer de l'un à l'autre sur la même base via ce script. Pour un instantané natif, une relance vérifie l'empreinte des fichiers SQL sans les réappliquer ni remplacer les modifications faites dans SSMS. Si les fichiers changent ou si l'initialisation était partielle, choisissez un nouveau nom; la base existante reste disponible pour diagnostic. Pour Flyway, les migrations et les données répétables suivent `flyway.toml` (`dev`); une migration de données modifiée peut remplacer `stg`.

Dans l'extension MSSQL de VS Code ou SSMS, connectez-vous à `.\SQLEXPRESS` en authentification Windows, puis choisissez `brulerie_demo_python`. `dw.client`, `dw.produit` et `stg.vente_brute` sont alimentées. Pour charger `dw.vente`, exécutez **une seule fois** `EXEC etl.usp_charger_ventes;` : sur `main`, une relance double les ventes par conception de l'atelier. Le provisionnement n'appelle pas cette procédure et ne supprime jamais sa base persistante.

### GitHub Actions

`.github/workflows/validation.yml` s'exécute sur chaque PR et chaque poussée sur `main`, avec la seule permission `contents: read`. Docker publie un port aléatoire sur `127.0.0.1`; pytest utilise ce port même lorsque Flyway s'exécute dans son image Docker. Les tests SQL existants sont conservés. Aucun secret externe ni déploiement.

Lancement manuel avec l'entrée `performance=true` : mesures et plans facultatifs conservés comme artefact `resultats-python`, même en cas d'échec. Aucun budget universel n'est imposé en CI.

### Azure Pipelines (Azure Repos)

1. **Pipelines** > **New pipeline** > **Azure Repos Git** > choisissez le dépôt > **Existing Azure Pipelines YAML file** > `/azure-pipelines.yml`.
2. Pour valider les PR : **Repos** > **Branches** > `main` > **Branch policies** > **Build validation** > ajoutez ce pipeline.
3. Agent auto-hébergé sans Docker : remplacez la valeur de la variable `modeValidation` par `LintSeulement`.

### Gabarits de PR

`.github/pull_request_template.md` (GitHub) et `.azuredevops/pull_request_template.md` (Azure Repos) ont le même contenu : clé du billet, résumé, cases migration, test et `valider.ps1` vert.

## Hook de garde-fous

Le hook `preToolUse` refuse de façon déterministe la lecture de `.env` (mais pas de `.env.example`), ainsi que `flyway clean` et `DROP DATABASE` dans une commande. Dans tous les autres cas, il rend `{}` : aucune décision, les confirmations habituelles s'appliquent.

- **Livré désactivé** (`.github/hooks/garde-fous.json.disabled`) : sous Windows, il exige PowerShell 7 (`pwsh`), et un hook qui ne peut pas s'exécuter peut faire refuser tous les outils.
- **Activer** (démo, poste avec PowerShell 7) : renommez le fichier en `.github/hooks/garde-fous.json`, puis ouvrez une nouvelle session. Ce nom est ignoré par Git : le hook activé n'est pas versionné par erreur.
- **Désactiver** : renommez-le en `garde-fous.json.disabled`.
- **Tester sans l'activer** : `pwsh ./scripts/valider.ps1 -Mode LintSeulement` (étape 3).

Les hooks sont en préversion dans VS Code; GitHub Copilot CLI sert de surface de repli pour la démo du hook. Un hook est un garde-fou, pas une frontière de sécurité : il ne remplace ni les permissions du poste ni la gestion des secrets.

## Dépannage

| Symptôme | Cause probable | Solution |
| --- | --- | --- |
| `Docker absent` ou démon arrêté | Docker non installé, non démarré ou interdit | Démarrez Docker Desktop; sinon `-Mode Local` (SQL Server local) ou `-Mode LintSeulement` |
| Téléchargement d'image très long ou refusé | Proxy ou registre bloqué | Pré-téléchargez la veille (`docker pull mcr.microsoft.com/mssql/server:2022-latest`, `docker pull redgate/flyway:13`); configurez le proxy de Docker Desktop |
| `pip install` ou appels d'API en délai dépassé | Proxy d'entreprise | Définissez `HTTPS_PROXY` dans la session; utilisez `-Simulation` pour les skills |
| Erreur 401 du skill `jira-ticket` | Jeton expiré ou mal copié, courriel absent (Cloud), mauvais `JIRA_DEPLOIEMENT` | Recréez le jeton et vérifiez `.env`. Cloud : courriel + jeton d'API; Data Center : PAT |
| Le hook ne se déclenche pas | Fichier encore en `.disabled`, harness Local sélectionné, ancienne session, hooks bloqués par une politique | Renommez en `garde-fous.json`, choisissez le Copilot harness dans **Session Target**, ouvrez une nouvelle session; sinon faites la démo dans GitHub Copilot CLI |
| Skills, agent ou hook absents dans VS Code | Harness Local encore sélectionné | Choisissez le Copilot harness dans le sélecteur **Session Target** de la vue Chat |
| Tous les outils sont refusés | Hook actif sans PowerShell 7 (`pwsh` introuvable) | Renommez le hook en `.disabled`; installez PowerShell 7 avant de le réactiver |
| `-Mode Local` : Flyway ne se connecte pas | Instance nommée sans TCP/IP ni SQL Server Browser | Faire configurer TCP/port par l'administrateur; sinon initialisation explicite `-MethodeSchema SqlcmdInitial` sur une base neuve, ou Docker |
| `Pilote absent` dans pytest | pyodbc installé, mais pilote ODBC absent ou mauvais nom | Installer ODBC Driver 18 séparément ou définir `PYTEST_ODBC_DRIVER` au nom exact du pilote 17 installé |
| Budget p95 dépassé | Volume, charge de l'instance ou budget inadapté | Consulter les échantillons et le plan conservés; ne pas conclure à une régression de production sur ce seul scénario |
| `[IGNORE]` pour le skill `jira-ticket` | Attendu sur `main` : le script contient des `TODO-ATELIER` | Complétez-les (étape 2) ou passez sur `etape-2` |
| Exécution de script refusée | Politique d'exécution de Windows PowerShell | `powershell -ExecutionPolicy Bypass -File ./scripts/valider.ps1` |

## Réinitialiser pour une nouvelle cohorte

1. Repartez d'une nouvelle copie du gabarit (**Use this template** ou [copie interne](#obtenir-une-copie-interne)) plutôt que de nettoyer l'ancienne.
2. Supprimez les branches et les PR des participants dans l'ancienne copie, ou archivez-la.
3. Révoquez les jetons Jira et les PAT Azure DevOps créés pour la journée.
4. Videz l'espace Jira de formation, puis réimportez [docs/tickets/import-jira.csv](docs/tickets/import-jira.csv).
5. Vérifiez que le hook est revenu en `.disabled` et qu'aucun `.env` n'est versionné (`git ls-files .env` ne rend rien).
6. Relancez la CI sur `main` et sur chaque branche `etape-*`.

## Sources

- [Retrait du harness Local de VS Code](https://github.blog/changelog/2026-11-16-vs-code-retires-the-local-harness-in-february-2027/) et [passer au Copilot harness](https://code.visualstudio.com/docs/agents/run/move-to-copilot)
- [Aide-mémoire des personnalisations GHCP](https://docs.github.com/en/copilot/reference/customization-cheat-sheet)
- [Agents personnalisés](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Hooks : référence](https://docs.github.com/en/copilot/reference/hooks-reference), [hooks dans GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks) et [hooks dans VS Code](https://code.visualstudio.com/docs/agent-customization/hooks)
- [Installer GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)
- [Commentaires d'éléments de travail Azure DevOps](https://learn.microsoft.com/rest/api/azure/devops/wit/comments/add-work-item-comment?view=azure-devops-rest-7.1)
- [API REST Jira Cloud v3](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Environnements Flyway](https://documentation.red-gate.com/flyway/reference/configuration/environments-namespace)
- [Installer Microsoft ODBC Driver sur Linux](https://learn.microsoft.com/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server?view=sql-server-ver17)
- [Plans réels avec STATISTICS XML et permissions](https://learn.microsoft.com/sql/t-sql/statements/set-statistics-xml-transact-sql?view=sql-server-ver17)
- [Enregistrer et ouvrir un plan XML dans SSMS](https://learn.microsoft.com/sql/relational-databases/performance/save-an-execution-plan-in-xml-format?view=sql-server-ver17)
