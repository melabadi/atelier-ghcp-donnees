# ATL-6 : documenter le modèle de données (bonus)

- **Type** : Tâche
- **Difficulté** : bonus
- **Étiquettes** : atelier, bonus, documentation

## Contexte

Les nouveaux membres de l'équipe découvrent le modèle en lisant les migrations une à une. L'équipe veut un diagramme à jour dans le dépôt.

## Critères d'acceptation

- [ ] Un fichier `docs/modele-donnees.md` contient un diagramme Mermaid `erDiagram` des tables des schémas `stg` et `dw`.
- [ ] Chaque colonne, clé primaire, clé étrangère et contrainte unique du diagramme existe dans `migrations/`, et inversement.
- [ ] Le flux `stg.vente_brute` → `etl.usp_charger_ventes` → `dw` est décrit en deux ou trois phrases.
- [ ] Le diagramme s'affiche dans l'aperçu Markdown de VS Code et sur la page du dépôt.

## Définition de « terminé »

1. `docs/modele-donnees.md` ajouté et relu contre les migrations.
2. `ATL-6` dans le titre et la description de la PR.

## Indice GHCP

Demandez à GHCP de tirer le diagramme des migrations seulement, puis demandez-lui de vérifier chaque colonne contre les fichiers `V*.sql`. Une documentation générée se vérifie comme du code.
