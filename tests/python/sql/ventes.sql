-- Objet : constater les conversions, les clés résolues et les montants réels.
SELECT
    v.numero_vente,
    c.code_client,
    p.code_produit,
    v.quantite,
    v.prix_unitaire,
    v.montant,
    CONVERT(VARCHAR(10), v.date_vente, 23) AS date_vente
FROM dw.vente AS v
INNER JOIN dw.client AS c ON v.id_client = c.id_client
INNER JOIN dw.produit AS p ON v.id_produit = p.id_produit
ORDER BY v.numero_vente;
