# ATL-3 : ajouter le courriel des clients

- **Type** : Story
- **Difficulté** : moyen
- **Étiquettes** : atelier, modele, sql

## Contexte

Le service à la clientèle veut joindre les clients par courriel. `dw.client` n'a pas de colonne pour le stocker, et rien n'empêche des valeurs mal formées.

## Critères d'acceptation

- [ ] `dw.client` a une colonne `courriel` `NVARCHAR(254) NULL`.
- [ ] Une contrainte `CHECK` refuse une valeur sans `@` ou sans point après le `@`; `NULL` reste permis.
- [ ] Deux clients ne peuvent pas avoir le même courriel (index unique filtré sur les valeurs non nulles).
- [ ] Les clients existants restent valides après la migration.
- [ ] Un test SQL vérifie qu'une valeur valide est acceptée et qu'une valeur invalide ou en double est refusée.

## Définition de « terminé »

1. Migration versionnée ajoutée dans `migrations/` (numéro suivant, jamais modifier `V3`).
2. Test ajouté dans `tests/sql/`.
3. `pwsh ./scripts/valider.ps1` vert.
4. `ATL-3` dans le titre et la description de la PR; commentaire de clôture dans le billet.

## Indice GHCP

Utilisez le skill explicite `/nouvelle-migration ajouter_courriel_client` : le numéro de version est calculé par script. Pour tester qu'une contrainte refuse une valeur, demandez un `TRY...CATCH` qui lève `THROW` si l'insertion réussit.
