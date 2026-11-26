# Exemple : commentaire Jira simulé pour ATL-2

Dernière étape de la boucle : une fois la CI verte, le skill `jira-ticket` commente le billet. Ici en simulation (`-Simulation`) : aucun appel réseau, aucun jeton.

Commande :

```powershell
$commentaire = "ATL-2 corrigé : etl.usp_charger_ventes ignore les ventes déjà chargées (NOT EXISTS sur numero_vente).`nTest de non-régression test_charger_ventes_idempotence.sql ajouté; valider.ps1 vert en CI."
pwsh ./.github/skills/jira-ticket/jira-ticket.ps1 -Action Commenter -Cle ATL-2 -Commentaire $commentaire -Simulation
```

Sortie obtenue (Jira Cloud, valeur par défaut sans `.env`) :

```text
[Simulation cloud] Aucun appel réseau. Requête qui serait envoyée :
POST {JIRA_URL}/rest/api/3/issue/ATL-2/comment
Corps : {"body":{"content":[{"content":[{"text":"ATL-2 corrigé : etl.usp_charger_ventes ignore les ventes déjà chargées (NOT EXISTS sur numero_vente).","type":"text"}],"type":"paragraph"},{"content":[{"text":"Test de non-régression test_charger_ventes_idempotence.sql ajouté; valider.ps1 vert en CI.","type":"text"}],"type":"paragraph"}],"version":1,"type":"doc"}}
Commentaire 10042 ajouté au billet ATL-2.
```

Avec Jira Data Center (`JIRA_DEPLOIEMENT=datacenter`), la requête vise `/rest/api/2/issue/ATL-2/comment` avec un corps `{"body": "texte"}`. Sans `-Simulation`, le même appel commente réellement le billet de l'espace de formation.

Demande équivalente dans GHCP : « Ajoute dans ATL-2 un commentaire qui résume la PR et le résultat de la CI. »
