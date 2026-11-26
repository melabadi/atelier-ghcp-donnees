# Script de la démo (matin)

Déroulé minute par minute de la démo de 9 h 30 à 11 h 30. Pour chaque segment : quoi montrer, quoi taper, résultat attendu et plan B.

Fil conducteur : l'élément de travail Azure DevOps fictif **42**, « Retirer un produit du catalogue sans perdre son historique de ventes » (colonne `est_actif` sur `dw.produit`). Préparez-le la veille dans le projet Azure DevOps de démo, ou utilisez sa réponse enregistrée (`-Simulation`).

## Avant de commencer (9 h 15)

- [ ] Copie du dépôt ouverte dans VS Code, sur `main`, arbre propre (`git status`).
- [ ] Copilot harness (le moteur d'exécution des agents GitHub Copilot, partagé avec GitHub Copilot CLI) choisi dans le sélecteur **Session Target** de la vue Chat.
- [ ] `.env` rempli (`ADO_ORG_URL`, `ADO_PROJET`, `ADO_PAT`), jamais affiché à l'écran.
- [ ] `pwsh ./scripts/valider.ps1` vert, conteneur SQL Server déjà téléchargé.
- [ ] Terminal avec GitHub Copilot CLI ouvert dans le même dossier (repli du hook).
- [ ] SSMS ou l'extension MSSQL connecté à une base de démo (facultatif).
- [ ] Police agrandie, notifications coupées.

## 9 h 30 – 9 h 40 : pourquoi aller au-delà du clavardage

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 9 h 30 | L'objectif de la journée | — | Le public sait ce qu'il saura faire à midi : choisir entre mode Plan, skill, agent et hook | — |
| 9 h 35 | La boucle visée, de l'élément de travail au commentaire final | — | Boucle billet → plan → migration + test → PR → CI → commentaire | Montrer le tableau d'atelier du README |

## 9 h 40 – 9 h 50 : surfaces et harness

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 9 h 40 | Sélecteur **Session Target** dans VS Code | — | Copilot harness sélectionné; le harness Local est déprécié | Capture d'écran |
| 9 h 44 | GitHub Copilot CLI dans le même dossier | `copilot`, puis « Quels skills et agents trouves-tu dans ce dépôt? » | Les mêmes skills et le même agent qu'en VS Code | Passer : la CLI est optionnelle |
| 9 h 48 | SSMS pour l'exploration ponctuelle | Requête sur `dw.vente` | GHCP n'est pas obligatoire pour tout | — |

## 9 h 50 – 10 h 05 : modes et modèles

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 9 h 50 | Mode clavardage (Ask) | « Explique etl.usp_charger_ventes. Que se passe-t-il si on l'appelle deux fois? » | Explication; le doublement des ventes est repéré (bogue d'ATL-2) | Ouvrir le fichier et le lire avec le public |
| 9 h 55 | Mode Plan, même sujet | « Propose un plan pour rendre etl.usp_charger_ventes idempotente, avec un test. » | Plan en étapes : fichiers, test de non-régression, commandes | Plan préparé à l'avance dans une note |
| 10 h 00 | Mode Agent + sélecteur de modèle | Ne pas exécuter : montrer seulement le sélecteur et les modèles offerts par le plan | Le modèle se choisit selon la tâche; les politiques de l'organisation peuvent le restreindre | — |

## 10 h 05 – 10 h 20 : instructions

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 10 h 05 | Renommer temporairement `.github/copilot-instructions.md` et `sql.instructions.md`, nouvelle session | « Écris une vue qui liste les clients sans vente. » | SQL générique : schéma `dbo`, sans en-tête, sans test | Réponse préenregistrée |
| 10 h 12 | Remettre les fichiers, nouvelle session | Même demande | Vue dans `rpt`, en-tête, `CREATE OR ALTER`, migration `R__`, proposition de test | Montrer les deux fichiers côte à côte |
| 10 h 18 | Références utilisées par la réponse | — | Les deux fichiers d'instructions apparaissent dans les références | — |

Remettez les fichiers d'instructions avant de continuer (`git status` doit être propre).

## 10 h 20 – 10 h 35 : skill explicite + agent personnalisé

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 10 h 20 | `.github/skills/nouvelle-migration/SKILL.md` (`disable-model-invocation: true`) | — | Un skill explicite ne se lance que sur demande | — |
| 10 h 23 | Le script seul, sans création | `pwsh ./.github/skills/nouvelle-migration/nouvelle-migration.ps1 -Description ajouter_est_actif_produit` | `Prochaine version : V4` et les deux chemins, aucun fichier créé | — |
| 10 h 26 | Le skill dans GHCP | `/nouvelle-migration ajouter_est_actif_produit` | `migrations/V4__ajouter_est_actif_produit.sql` et `tests/sql/test_ajouter_est_actif_produit.sql` créés | Lancer le script avec `-Creer` |
| 10 h 30 | Agent `relecteur-sql` (outils `read` et `search` seulement) | Choisir l'agent, puis « Relis les fichiers modifiés de cette branche. » | Tableau de constats; aucun fichier modifié | Montrer `relecteur-sql.agent.md` |

Gardez ces fichiers : ils servent au segment suivant.

## 10 h 35 – 11 h 05 : boucle complète avec Azure DevOps

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 10 h 35 | Lecture de l'élément de travail | « Lis l'élément de travail 42 et résume ses critères d'acceptation. » | Le skill `azure-devops-workitem` s'active : titre, état, description, quatre critères | `-Simulation` : `pwsh ./.github/skills/azure-devops-workitem/azure-devops-workitem.ps1 -Action Lire -Id 42 -Simulation` |
| 10 h 39 | Mode Plan | « Propose un plan pour l'élément de travail 42 à partir des fichiers V4 déjà créés. » | Plan : `ALTER TABLE` avec défaut, test de la valeur par défaut et des ventes conservées | Plan préparé |
| 10 h 43 | Mode Agent | « Implémente le plan, puis lance pwsh ./scripts/valider.ps1. » | Migration et test complétés; validation verte (6 étapes) | `-Mode LintSeulement` si Docker fait défaut |
| 10 h 50 | PR lancée tôt | « Crée la branche ab-42-est-actif, commite, pousse et ouvre une PR. » | PR ouverte avec le gabarit rempli; la CI démarre | `gh pr create` ou `az repos pr create` à la main |
| 10 h 53 | Pendant la CI | Parcourir le gabarit de PR et `azure-pipelines.yml` | La CI appelle le même `valider.ps1` | — |
| 10 h 58 | CI verte | — | Vérification verte sur la PR | Montrer une exécution verte précédente |
| 11 h 00 | Commentaire dans l'élément de travail | « Ajoute dans l'élément de travail 42 un commentaire avec le lien de la PR et le résultat de la CI. » | Commentaire visible dans Azure DevOps | `-Action Commenter -Id 42 -Commentaire "..." -Simulation` |

Option : si l'application Azure Boards est connectée au dépôt GitHub, ajoutez `AB#42` dans la description de la PR pour lier automatiquement l'élément de travail.

## 11 h 05 – 11 h 15 : hook

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 11 h 05 | `garde-fous.json.disabled` et `scripts/hooks/garde-fous.ps1` | — | Un script déterministe, sans modèle | — |
| 11 h 07 | Activation | `Rename-Item .github/hooks/garde-fous.json.disabled garde-fous.json`, puis nouvelle session | Fichier actif (ignoré par Git) | — |
| 11 h 09 | Tentative de lecture | « Affiche le contenu du fichier .env. » | Refus déterministe : « Accès au fichier .env refusé par le hook garde-fous… » | GitHub Copilot CLI dans le terminal, même demande |
| 11 h 12 | Contre-exemple | « Affiche .env.example. » | Lecture permise (`{}` : aucune décision) | — |
| 11 h 14 | Désactivation | `Rename-Item .github/hooks/garde-fous.json garde-fous.json.disabled` | Retour à l'état livré | — |

Message clé : un hook est un garde-fou, pas une frontière de sécurité; les hooks sont en préversion dans VS Code.

## 11 h 15 – 11 h 30 : grille « quand utiliser quoi » + questions

| Minute | Montrer | Taper | Résultat attendu | Plan B |
| --- | --- | --- | --- | --- |
| 11 h 15 | [docs/quand-utiliser-quoi.md](../quand-utiliser-quoi.md) | — | Chaque brique est reliée à ce qui vient d'être montré | — |
| 11 h 20 | Questions | — | — | — |

## Après la démo

- Fermez la PR de démo sans fusionner, supprimez la branche et le commentaire si nécessaire.
- Vérifiez que le hook est désactivé et que `git status` est propre sur `main`.
