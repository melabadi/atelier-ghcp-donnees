# ATL-5 : skill confluence-page en lecture seule (bonus)

- **Type** : Story
- **Difficulté** : bonus
- **Étiquettes** : atelier, bonus, ghcp, skill

## Contexte

Les règles de gestion des données sont documentées dans des pages Confluence. L'équipe veut que GHCP puisse lire une page pour s'en servir comme contexte, sans jamais la modifier.

## Critères d'acceptation

- [ ] Un skill `.github/skills/confluence-page/` (`SKILL.md` + script PowerShell) lit une page par son identifiant et en rend le titre et le texte brut.
- [ ] Le script ne fait que des requêtes `GET`; aucune action d'écriture n'est proposée.
- [ ] L'URL et le jeton sont lus dans `.env` par le script (variables ajoutées sans valeur à `.env.example`); le jeton n'est jamais affiché.
- [ ] Le mode `-Simulation` lit une fixture dans `tests/fixtures/`.
- [ ] Un test `tests/skills/confluence-page.Tests.ps1` vérifie la lecture simulée, une erreur 401 et l'absence du jeton dans la sortie.

## Définition de « terminé »

1. Skill, fixtures et test ajoutés.
2. `pwsh ./scripts/valider.ps1 -Mode LintSeulement` vert (étapes 2 et 4).
3. `ATL-5` dans le titre et la description de la PR.

## Indice GHCP

Demandez de reprendre la structure de `jira-ticket` (lecture de `.env`, `-Simulation`, messages d'erreur sans en-tête). Vérifiez la description du skill : c'est elle qui permet à l'agent de l'utiliser au bon moment.
