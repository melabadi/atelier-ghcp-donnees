---
name: azure-devops-workitem
description: Lit un élément de travail Azure DevOps (titre, état, description, critères d'acceptation) ou y ajoute un commentaire, par l'API REST avec un PAT lu dans .env par le script. À utiliser quand une demande mentionne un élément de travail Azure DevOps (numéro, AB#123) ou demande d'y rendre compte d'un travail terminé.
---

# Élément de travail Azure DevOps

Le script `azure-devops-workitem.ps1` appelle l'API REST d'Azure DevOps. Il lit lui-même `ADO_ORG_URL`, `ADO_PROJET` et `ADO_PAT` dans `.env` : le jeton n'entre jamais dans la conversation. N'ouvrez pas `.env` et ne demandez jamais le jeton.

## Lire un élément de travail

```powershell
pwsh ./.github/skills/azure-devops-workitem/azure-devops-workitem.ps1 -Action Lire -Id 42
```

Le script rend le type, le titre, l'état, la description et les critères d'acceptation en texte brut. Servez-vous des critères d'acceptation pour planifier le travail (mode Plan) avant de modifier des fichiers.

## Commenter un élément de travail

```powershell
pwsh ./.github/skills/azure-devops-workitem/azure-devops-workitem.ps1 -Action Commenter -Id 42 -Commentaire "Migration V4 et test ajoutés; PR ouverte, CI verte."
```

Le commentaire est envoyé en Markdown. Montrez le texte à la personne avant de l'envoyer : un commentaire publié est visible par toute l'équipe.

## Mode simulation (plan B réseau)

Ajoutez `-Simulation` pour utiliser les réponses enregistrées de `tests/fixtures/` au lieu de l'API (élément 42 disponible). Aucun appel réseau, aucun jeton requis.

## Erreurs fréquentes

- 401 : PAT absent, expiré ou mal copié dans `.env`.
- 403 : le PAT n'a pas la portée Work Items (lecture et écriture) ou le projet n'est pas accessible.
- 404 : numéro d'élément, organisation ou projet incorrect.
