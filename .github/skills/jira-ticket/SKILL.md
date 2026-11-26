---
name: jira-ticket
description: Lit un billet Jira (résumé, état, description) ou y ajoute un commentaire, par l'API REST de Jira Cloud ou Data Center, avec un jeton lu dans .env par le script. À utiliser quand une demande mentionne une clé de billet Jira (p. ex. ATL-1) ou demande d'y rendre compte d'un travail terminé.
---

# Billet Jira

Le script `jira-ticket.ps1` appelle l'API REST de Jira. Il lit lui-même `JIRA_URL`, `JIRA_DEPLOIEMENT`, `JIRA_COURRIEL` et `JIRA_JETON` dans `.env` : le jeton n'entre jamais dans la conversation. N'ouvrez pas `.env` et ne demandez jamais le jeton.

> Atelier : branche `etape-2`, version complète du script. Les trois fonctions marquées `# TODO-ATELIER` sur `main` y sont réalisées et les tests de simulation (`tests/skills/jira-ticket.Tests.ps1`) sont actifs.

| Déploiement (`JIRA_DEPLOIEMENT`) | Authentification | API | Format des textes |
| --- | --- | --- | --- |
| `cloud` | Basic : courriel + jeton d'API | `/rest/api/3/issue/{cle}` | Atlassian Document Format (ADF) |
| `datacenter` | Bearer : jeton d'accès personnel (PAT) | `/rest/api/2/issue/{cle}` | Texte brut |

## Lire un billet

```powershell
pwsh ./.github/skills/jira-ticket/jira-ticket.ps1 -Action Lire -Cle ATL-1
```

Le script rend le type, le résumé, l'état et la description en texte brut. Servez-vous des critères d'acceptation de la description pour planifier le travail (mode Plan) avant de modifier des fichiers.

## Commenter un billet

```powershell
pwsh ./.github/skills/jira-ticket/jira-ticket.ps1 -Action Commenter -Cle ATL-1 -Commentaire "Vue et test ajoutés; PR ouverte, CI verte."
```

Montrez le texte à la personne avant de l'envoyer : un commentaire publié est visible par toute l'équipe.

## Mode simulation (plan B réseau)

Ajoutez `-Simulation` pour utiliser les réponses enregistrées de `tests/fixtures/` (billet ATL-1, en Cloud et en Data Center selon `JIRA_DEPLOIEMENT`). Aucun appel réseau, aucun jeton requis.

## Erreurs fréquentes

- 401 : jeton absent, expiré ou mal copié; en Cloud, courriel absent ou différent du compte du jeton; `JIRA_DEPLOIEMENT` incorrect.
- 403 : le compte n'a pas le droit de voir ou de commenter ce billet.
- 404 : clé de billet ou `JIRA_URL` incorrect, ou billet invisible pour ce compte.
