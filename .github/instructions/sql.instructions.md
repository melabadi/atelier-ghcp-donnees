---
applyTo: "**/*.sql"
---

# Conventions T-SQL

## En-tête de fichier

Chaque fichier SQL commence par un commentaire de quelques lignes : nom du fichier, objet créé ou modifié et son but, billet associé si connu.

```sql
-- Migration : R__rpt_v_exemple.sql (répétable)
-- Objet     : vue rpt.v_exemple, qui résume les ventes par mois.
-- Billet    : ATL-1
```

## Nommage

- Identifiants en français, sans accents, en snake_case : `dw.vente`, `date_vente`, `id_client`.
- Tables au singulier. Clé primaire de substitution : `id_<table>`.
- Contraintes : `pk_<table>`, `fk_<table>_<table_ref>`, `uq_<table>_<colonne>`, `ck_<table>_<regle>`, `df_<table>_<colonne>`.
- Index : `ix_<table>_<colonnes>`. Vues : `v_<sujet>`. Procédures : `usp_<verbe>_<objet>`.
- Toujours qualifier par le schéma (`dw.client`, jamais `client`).

## Migrations Flyway

- DDL dans une migration versionnée `V<n>__<description>.sql`, jamais modifiée après fusion.
- Procédures et vues dans une migration répétable `R__<schema>_<objet>.sql` avec `CREATE OR ALTER`.
- Séparateur de lots `GO` au besoin (une instruction `CREATE SCHEMA`, `CREATE VIEW` ou `CREATE PROCEDURE` par lot).
- Pas de `${` dans le SQL (paramètre de substitution Flyway).

## Idempotence et transactions

- Un chargement peut être relancé sans créer de doublons : vérifiez l'existence (`NOT EXISTS`, `MERGE`) sur une clé métier.
- Les procédures qui écrivent utilisent `SET XACT_ABORT ON`, `BEGIN TRY ... BEGIN TRANSACTION ... COMMIT` et, dans le `CATCH`, `IF @@TRANCOUNT > 0 ROLLBACK` puis `THROW`.
- Conversions de données brutes avec `TRY_CONVERT`; les lignes invalides sont exclues ou rejetées, jamais converties de force.

## Style

- Pas de `SELECT *` : nommez les colonnes.
- Mots-clés, fonctions et types en majuscules; lignes de 120 caractères au plus (règles dans `.sqlfluff`).
- Jointures explicites (`INNER JOIN ... ON`), alias courts et significatifs.
- Littéraux texte Unicode : `N'...'`.

## Tests

- Un fichier `tests/sql/test_<sujet>.sql` par sujet; chaque attente non respectée lève `THROW 50xxx, N'message', 1;`.
- Les tests qui écrivent des données s'exécutent dans `BEGIN TRANSACTION ... ROLLBACK TRANSACTION`.
- Les tests sont déterministes : pas de `GETDATE()` dans les attentes, pas de dépendance à l'ordre d'exécution des fichiers.
