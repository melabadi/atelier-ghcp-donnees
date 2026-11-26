# Billets de l'atelier

| Clé | Billet | Difficulté |
| --- | --- | --- |
| ATL-1 | [Créer la vue rpt.v_ventes_mensuelles](ATL-1.md) | Facile |
| ATL-2 | [Rendre etl.usp_charger_ventes idempotente](ATL-2.md) | Moyen |
| ATL-3 | [Ajouter le courriel des clients](ATL-3.md) | Moyen |
| ATL-4 | [Envoyer les quantités invalides vers une table de rejets](ATL-4.md) | Moyen+ |
| ATL-5 | [Skill confluence-page en lecture seule](ATL-5.md) | Bonus |
| ATL-6 | [Documenter le modèle de données](ATL-6.md) | Bonus |

## Importer dans l'espace Jira de formation

1. Créez un projet de formation dont la clé est `ATL` (les billets recevront ATL-1 à ATL-6 s'ils sont importés dans l'ordre, dans un projet vide).
2. Importez [import-jira.csv](import-jira.csv) (UTF-8, séparateur virgule) avec l'outil d'importation CSV de Jira.
3. Associez les colonnes : `Résumé` → Summary, `Description` → Description, `Type` → Issue Type, chaque colonne `Étiquettes` → Labels.
4. Les types sont `Story`, `Bug` et `Task`; associez-les aux types équivalents de votre projet si leurs noms diffèrent.

La description utilise la syntaxe de mise en forme Jira (`h3.`, `*`). Les fichiers Markdown de ce dossier restent la référence et servent de plan B sans réseau.
