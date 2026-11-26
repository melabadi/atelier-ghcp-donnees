# Instructions du dépôt pour GitHub Copilot

Ce dépôt est un petit projet SQL Server + Flyway pour une brûlerie de café fictive (« Brûlerie Démo »). Toutes les données sont fictives.

## Structure

- `migrations/` : migrations Flyway. `V<n>__<description>.sql` pour le DDL (jamais modifiées une fois fusionnées); `R__<description>.sql` pour les procédures et les vues (`CREATE OR ALTER`).
- `donnees-exemple/` : données d'exemple idempotentes, chargées seulement dans les environnements Flyway `dev` et `ci`.
- `tests/sql/test_<sujet>.sql` : tests déterministes; chaque attente non respectée lève `THROW`; les tests qui écrivent s'exécutent dans une transaction annulée.
- `scripts/valider.ps1` : validation unique (lint, personnalisations, hook, skills, Flyway, tests SQL), en local comme en CI.
- `.github/skills/`, `.github/agents/`, `.github/instructions/`, `.github/hooks/` : personnalisations GitHub Copilot.

## Commandes

- Validation complète : `pwsh ./scripts/valider.ps1` (Docker), `-Mode Local` (instance existante, `.env`) ou `-Mode LintSeulement`.
- Lint seul : `sqlfluff lint migrations donnees-exemple tests/sql`.
- Prochaine migration : skill `nouvelle-migration`.

## Conventions

- Schémas : `stg` (brut), `dw` (modèle), `rpt` (vues de rapport), `etl` (procédures de chargement).
- Identifiants SQL en français, sans accents, en snake_case. Mots-clés T-SQL en majuscules.
- Une nouvelle migration versionnée prend le numéro suivant le plus grand `V<n>` existant; ne renumérotez jamais une migration existante.
- Pas de `${` dans les fichiers SQL : Flyway l'interprète comme un paramètre de substitution.
- Ne lisez jamais `.env` et n'affichez jamais de jeton; les scripts de skills lisent `.env` eux-mêmes.

## Définition de « terminé »

1. Migration (ou objet répétable) ajoutée dans `migrations/`.
2. Test SQL ajouté ou mis à jour dans `tests/sql/`.
3. `pwsh ./scripts/valider.ps1` vert.
4. Clé du billet (p. ex. `ATL-2`) dans le titre et la description de la demande de tirage (PR).

## Langue

Réponses, commentaires et documentation en français canadien. Noms de produits, commandes et mots-clés en anglais. Écrivez « GitHub Copilot » ou « GHCP », jamais le nom du produit seul.
