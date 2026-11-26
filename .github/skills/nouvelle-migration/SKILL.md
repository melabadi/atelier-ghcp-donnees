---
name: nouvelle-migration
description: Crée la prochaine migration Flyway versionnée (V<n>__<description>.sql) et son test SQL, avec un numéro de version calculé de façon déterministe par un script. À invoquer explicitement avec /nouvelle-migration quand un billet demande un changement de schéma.
disable-model-invocation: true
---

# Nouvelle migration

Ce skill crée, dans l'ordre, la prochaine migration versionnée et son test. Le numéro de version n'est jamais deviné : il est calculé par le script `nouvelle-migration.ps1` (plus grand `V<n>` de `migrations/` + 1).

## Étapes

1. Choisissez une description courte en snake_case, sans accents, qui commence par un verbe : `ajouter_courriel_client`, `creer_table_rejet_vente`.
2. Affichez le prochain numéro sans rien créer :

   ```powershell
   pwsh ./.github/skills/nouvelle-migration/nouvelle-migration.ps1 -Description ajouter_courriel_client
   ```

3. Créez les deux fichiers (migration et test) à partir des modèles :

   ```powershell
   pwsh ./.github/skills/nouvelle-migration/nouvelle-migration.ps1 -Description ajouter_courriel_client -Creer
   ```

4. Remplissez la migration en suivant `.github/instructions/sql.instructions.md` : en-tête, schéma explicite, contraintes nommées.
5. Remplacez l'attente factice du test par de vraies vérifications qui lèvent `THROW` en cas d'échec, dans une transaction annulée.
6. Lancez `pwsh ./scripts/valider.ps1` (ou `-Mode LintSeulement` sans Docker) et corrigez jusqu'à ce que tout soit vert.

## Règles

- Une vue ou une procédure va dans une migration répétable `R__<schema>_<objet>.sql` avec `CREATE OR ALTER`, pas dans une migration versionnée : ce skill ne sert alors qu'à créer le test.
- Ne renumérotez jamais une migration existante et ne modifiez pas une migration déjà fusionnée.
- Le script refuse d'écraser un fichier existant.
