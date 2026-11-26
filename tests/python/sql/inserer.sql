-- Objet : ajouter un cas paramétré; les paramètres ODBC ne sont pas interpolés.
INSERT INTO stg.vente_brute (
    numero_vente, date_vente, code_client, code_produit, quantite, prix_unitaire
)
VALUES (?, ?, ?, ?, ?, ?);
