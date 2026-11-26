# Guide de l'animateur et des coachs

Pour une vingtaine de participants, un animateur et deux ou trois coachs.

## Organisation de la salle

- **Tables mixtes** : quatre ou cinq personnes par table, en mélangeant profils (ingénierie de données, analyse, plateforme) et niveaux d'aisance avec GitHub Copilot (GHCP). Chacun travaille sur son poste, mais la table s'entraide d'abord.
- **Un coach pour deux tables**, au plus.
- **Un écran partagé** reste sur le tableau de l'atelier du [README](../../README.md#atelier-après-midi), avec l'heure de chaque étape.

## Rôle des coachs

- Faire verbaliser avant de corriger : « Qu'as-tu demandé? Qu'a répondu GHCP? Qu'attendais-tu? »
- Aider à reformuler la demande (contexte, fichier visé, résultat attendu), plutôt que de taper à la place du participant.
- Repérer les blocages d'environnement (Docker, proxy, jeton, harness) et les régler vite avec la section [Dépannage](../../README.md#dépannage).
- Faire respecter la règle des 10 minutes.
- Noter les questions récurrentes pour le retour de 15 h 05.
- Ne jamais demander un jeton, ni le regarder à l'écran.

## Règle de rattrapage

Bloqué plus de 10 minutes sur une étape : on passe sur la branche de cette étape et on continue.

```powershell
git stash push -u -m "mon travail"   # facultatif : garder ses essais
git switch etape-<n>
pwsh ./scripts/valider.ps1 -Mode LintSeulement
```

| Étape | Branche | Contenu |
| --- | --- | --- |
| Fichier d'instructions | `etape-1` | Instructions avec un exemple de conventions d'équipe |
| Jeton Jira + skill | `etape-2` | Skill `jira-ticket` complet, tests de simulation activés |
| Boucle complète | `etape-3` | ATL-1 réalisé (migration + test) |
| Boucle complète | `etape-4` | ATL-2 corrigé, test de non-régression, exemple de description de PR, commentaire Jira simulé |

Rattraper n'est pas un échec : l'objectif est de vivre toute la boucle.

## Défis bonus

Pour les tables en avance :

1. **ATL-5** : créer un skill `confluence-page` en lecture seule, sur le modèle de `jira-ticket` (script, `-Simulation`, fixtures, test).
2. **ATL-6** : faire générer par GHCP un diagramme Mermaid du modèle de données à partir des migrations, et le vérifier contre `migrations/`.
3. Créer son propre agent personnalisé (p. ex. rédacteur de description de PR, outils en lecture seule).
4. Écrire un test de non-régression pour un billet qu'une autre table a terminé.
5. Activer le hook sur un poste avec PowerShell 7 et ajouter une règle (p. ex. refuser `TRUNCATE TABLE dw.`), avec sa fixture dans `tests/hooks/`.

## Liste de vérification de la veille

- [ ] CI verte sur `main` et sur chaque branche `etape-*` dans la copie interne.
- [ ] Billets ATL-1 à ATL-6 importés dans l'espace Jira de formation ([import-jira.csv](../tickets/import-jira.csv)).
- [ ] Chaque participant a accès à l'espace Jira de formation et sait créer son jeton (ou jetons créés à l'avance selon la politique).
- [ ] Élément de travail de démo préparé dans Azure DevOps; PAT de l'animateur valide (portée Work Items).
- [ ] Images Docker pré-téléchargées sur les postes : `mcr.microsoft.com/mssql/server:2022-latest` et `redgate/flyway:13`.
- [ ] Accès réseau et VPN testés depuis la salle : dépôt interne, Jira, Azure DevOps, registres d'images, PyPI.
- [ ] `pwsh ./scripts/verifier-poste.ps1` exécuté sur un poste type, sans `[MANQUANT]`.
- [ ] Politiques GHCP vérifiées : Copilot harness, hooks, GitHub Copilot CLI, modèles offerts.
- [ ] Hook désactivé dans la copie interne (`.github/hooks/garde-fous.json.disabled`).

## Liste de vérification du jour J

- [ ] Salle : prises, projecteur, Wi-Fi ou réseau filaire, tables mixtes formées.
- [ ] Poste de démo : [préparation du script de démo](script-demo.md#avant-de-commencer-9-h-15) faite.
- [ ] Coachs présentés, répartis par table.
- [ ] À 13 h 00 : chaque table confirme `valider.ps1` vert avant l'étape 1.
- [ ] À 13 h 35 : rappel « ne collez jamais un jeton dans le clavardage ».
- [ ] À 14 h 05 : chaque table a choisi un billet.
- [ ] À 15 h 05 : retour par table (ce qui a marché, ce qui a bloqué, ce qu'on adopte dès lundi).
- [ ] Fin de journée : rappeler de révoquer les jetons et de supprimer les `.env` locaux.
