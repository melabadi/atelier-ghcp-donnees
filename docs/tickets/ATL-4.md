# ATL-4 : envoyer les quantités invalides vers une table de rejets

- **Type** : Story
- **Difficulté** : moyen+
- **Étiquettes** : atelier, etl, qualite, sql

## Contexte

La source envoie parfois des ventes avec une quantité nulle ou négative (retours mal saisis). La contrainte `ck_vente_quantite` de `dw.vente` fait alors échouer tout le chargement. L'équipe veut charger les lignes valides et isoler les autres pour analyse.

## Critères d'acceptation

- [ ] Une table `stg.vente_rejet` reçoit les lignes de `stg.vente_brute` dont la quantité convertie est ≤ 0, avec le motif du rejet et la date du rejet.
- [ ] `etl.usp_charger_ventes` charge les autres lignes valides sans échouer.
- [ ] Une ligne rejetée n'apparaît jamais dans `dw.vente`.
- [ ] Un test SQL insère une ligne avec une quantité de 0 et une autre avec -2, appelle la procédure et vérifie les deux rejets et le chargement des lignes valides.
- [ ] Les tests existants restent verts.

## Définition de « terminé »

1. Migration versionnée (table de rejets) et procédure mise à jour dans `migrations/`.
2. Test ajouté dans `tests/sql/`.
3. `pwsh ./scripts/valider.ps1` vert.
4. `ATL-4` dans le titre et la description de la PR; commentaire de clôture dans le billet.

## Indice GHCP

Faites d'abord un plan en mode Plan : deux fichiers changent (une migration versionnée, une répétable). Si ATL-2 est déjà fait dans votre branche, demandez à GHCP de préserver l'idempotence.
