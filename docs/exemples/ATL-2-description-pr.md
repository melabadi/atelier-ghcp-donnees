# Exemple : description de PR pour ATL-2

Exemple de rattrapage de l'étape 3 (branche `etape-4`). Titre de la PR :

```text
ATL-2 : rendre etl.usp_charger_ventes idempotente
```

Description, selon le gabarit `.github/pull_request_template.md` :

```markdown
## Billet

Clé : ATL-2

## Résumé

Un chargement relancé doublait les ventes : `etl.usp_charger_ventes` insérait toutes les lignes de `stg.vente_brute` à chaque appel. La procédure ignore maintenant toute vente déjà présente dans `dw.vente`, reconnue par son `numero_vente` (`NOT EXISTS`); un deuxième appel renvoie `@nb_lignes_inserees = 0`.

Revue de l'agent `relecteur-sql` : <résumez ici ses remarques et ce que vous avez retenu>.

## Vérifications

- [x] Migration ajoutée ou mise à jour dans `migrations/` (aucune migration `V<n>__` existante modifiée)
- [x] Test SQL ajouté ou mis à jour dans `tests/sql/`
- [x] `pwsh ./scripts/valider.ps1` vert
```

Fichiers modifiés :

- `migrations/R__etl_usp_charger_ventes.sql` : condition `NOT EXISTS` sur `dw.vente.numero_vente`.
- `tests/sql/test_charger_ventes_idempotence.sql` : appelle la procédure deux fois; échoue avant la correction (`THROW 50501`), réussit après.

Le commentaire de clôture du billet est dans [ATL-2-commentaire-jira.md](ATL-2-commentaire-jira.md).
