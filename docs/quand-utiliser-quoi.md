# Quand utiliser quoi

Grille de décision des briques de GitHub Copilot (GHCP) présentées pendant la journée. Chaque exemple pointe vers un fichier de ce dépôt.

Règle générale : commencez par la brique la plus légère qui répond au besoin. Passez à la suivante quand vous répétez la même consigne, la même procédure ou la même vérification.

| Brique | Quand l'utiliser | Exemple tiré du dépôt | Ce que ce n'est pas |
| --- | --- | --- | --- |
| Mode clavardage (Ask) | Comprendre, expliquer ou explorer sans modifier de fichier | « Explique ce que fait `etl.usp_charger_ventes` et pourquoi un deuxième appel double les ventes. » | Pas un moyen de modifier le dépôt : vous copiez vous-même ce qui vous convient |
| Mode Plan | Avant une tâche qui touche plusieurs fichiers, pour valider l'approche avant le code | « Lis ATL-2 et propose un plan : migration, test de non-régression, commandes de vérification. » | Pas une implémentation : le plan se relit et se corrige avant d'être confié au mode Agent |
| Mode Agent | Réaliser une tâche de bout en bout : modifier des fichiers, lancer `valider.ps1`, corriger | « Implémente le plan d'ATL-1, puis lance `pwsh ./scripts/valider.ps1 -Mode LintSeulement`. » | Pas un pilote automatique : vous approuvez les commandes et relisez le résultat |
| Instructions du dépôt | Conventions qui valent pour toute demande dans ce dépôt | [`.github/copilot-instructions.md`](../.github/copilot-instructions.md) : schémas, définition de « terminé », langue | Pas une procédure pas à pas, ni un endroit pour des secrets ou des règles à faire respecter de force |
| Instructions par chemin | Conventions propres à un type de fichier | [`.github/instructions/sql.instructions.md`](../.github/instructions/sql.instructions.md) (`applyTo: "**/*.sql"`) : en-têtes, `CREATE OR ALTER`, tests | Pas chargées pour les autres fichiers; pas un linter (c'est `sqlfluff` qui vérifie) |
| Skill invoqué automatiquement | Capacité outillée que l'agent choisit d'utiliser selon la demande | [`azure-devops-workitem`](../.github/skills/azure-devops-workitem/SKILL.md) et [`jira-ticket`](../.github/skills/jira-ticket/SKILL.md) se déclenchent quand une demande cite un élément de travail ou un billet | Pas une intégration permanente : un script lancé à la demande, qui lit son jeton dans `.env` sans l'exposer |
| Skill explicite | Procédure que vous voulez déclencher vous-même, au bon moment | `/nouvelle-migration` ([`SKILL.md`](../.github/skills/nouvelle-migration/SKILL.md), `disable-model-invocation: true`) : numéro de version calculé par script | Pas un fichier de prompt : il regroupe instructions et script, et le modèle ne le lance pas de lui-même |
| Agent personnalisé | Rôle spécialisé avec des outils limités, réutilisable par toute l'équipe | [`relecteur-sql`](../.github/agents/relecteur-sql.agent.md) : revue T-SQL en lecture seule (`tools: ["read", "search"]`) | Pas un humain relecteur ni une approbation de PR : ses constats se vérifient |
| Hook | Contrôle déterministe à un moment précis, sans dépendre du modèle | [`garde-fous.json.disabled`](../.github/hooks/garde-fous.json.disabled) + [`garde-fous.ps1`](../scripts/hooks/garde-fous.ps1) : refuse la lecture de `.env`, `flyway clean`, `DROP DATABASE` | Pas une frontière de sécurité : un garde-fou en préversion dans VS Code, qui ne remplace ni les permissions ni la gestion des secrets |
| MCP et connecteurs | Accès riche et continu à un service externe, géré et gouverné par l'organisation | Aucun dans ce dépôt (hors périmètre); les skills `jira-ticket` et `azure-devops-workitem` couvrent le besoin de la journée par scripts | Pas nécessaires pour deux appels d'API simples; pas à ajouter sans validation de l'organisation (connecteurs en préversion) |

## En une phrase

- **Mode clavardage (Ask)** : pour comprendre avant d'agir.
- **Mode Plan** : pour décider de l'approche avant d'écrire du code.
- **Mode Agent** : pour exécuter un plan validé, sous votre supervision.
- **Instructions du dépôt** : pour ne plus répéter les conventions de l'équipe.
- **Instructions par chemin** : pour des règles propres à un type de fichier, chargées seulement quand il est en jeu.
- **Skill invoqué automatiquement** : pour donner à l'agent une capacité outillée qu'il utilise quand la demande s'y prête.
- **Skill explicite** : pour une procédure que vous déclenchez vous-même, quand l'ordre des étapes compte.
- **Agent personnalisé** : pour un rôle réutilisable aux outils limités.
- **Hook** : pour ce qui doit arriver à coup sûr, quel que soit le modèle.
- **MCP et connecteurs** : pour un accès durable et gouverné à un service, quand un script ne suffit plus.
