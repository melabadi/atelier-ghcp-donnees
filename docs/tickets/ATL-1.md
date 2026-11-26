# ATL-1 : créer la vue rpt.v_ventes_mensuelles

- **Type** : Story
- **Difficulté** : facile
- **Étiquettes** : atelier, rapport, sql

## Contexte

L'équipe de rapports veut le chiffre d'affaires et la quantité vendue par mois, par produit. Aujourd'hui, chacun réécrit l'agrégation sur `dw.vente`, avec des résultats qui divergent.

## Critères d'acceptation

- [ ] La vue `rpt.v_ventes_mensuelles` expose `annee_mois`, `code_produit`, `quantite_totale` et `montant_total`.
- [ ] `annee_mois` est au format `AAAA-MM`; `montant_total` = somme de `quantite * prix_unitaire`.
- [ ] La vue est créée dans une migration répétable (`R__`) avec `CREATE OR ALTER`.
- [ ] Un test SQL vérifie les totaux sur un jeu de données connu.

## Définition de « terminé »

1. Migration répétable ajoutée dans `migrations/`.
2. Test ajouté dans `tests/sql/`.
3. `pwsh ./scripts/valider.ps1` vert.
4. `ATL-1` dans le titre et la description de la PR; commentaire de clôture dans le billet.

## Indice GHCP

Commencez en mode Plan à partir du billet (skill `jira-ticket`). Une vue n'est pas une migration versionnée : `/nouvelle-migration` n'est pas nécessaire, mais les instructions `sql.instructions.md` s'appliquent.
