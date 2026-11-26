# ATL-2 : rendre etl.usp_charger_ventes idempotente

- **Type** : Bogue
- **Difficulté** : moyen
- **Étiquettes** : atelier, etl, qualite, sql

## Contexte

Un chargement relancé après un incident a doublé les ventes du mois dans les rapports. `etl.usp_charger_ventes` insère toutes les lignes de `stg.vente_brute` à chaque appel, même celles déjà présentes dans `dw.vente`.

## Critères d'acceptation

- [ ] Deux appels successifs de `etl.usp_charger_ventes` donnent le même contenu de `dw.vente` qu'un seul appel.
- [ ] Le deuxième appel renvoie `@nb_lignes_inserees = 0`.
- [ ] Une vente déjà chargée est reconnue par son `numero_vente`.
- [ ] Un test de non-régression appelle la procédure deux fois et le vérifie.
- [ ] Le test existant `test_charger_ventes.sql` reste vert.

## Définition de « terminé »

1. Procédure corrigée dans `migrations/R__etl_usp_charger_ventes.sql`.
2. Test de non-régression ajouté dans `tests/sql/`.
3. `pwsh ./scripts/valider.ps1` vert.
4. `ATL-2` dans le titre et la description de la PR; commentaire de clôture dans le billet.

## Indice GHCP

Demandez d'abord en mode clavardage pourquoi un deuxième appel double les ventes. Faites ensuite écrire le test qui échoue avant la correction, puis la correction. Demandez une revue à l'agent `relecteur-sql`.
