-- Migration : R__rpt_v_ventes_mensuelles.sql (répétable)
-- Objet     : vue rpt.v_ventes_mensuelles, qui totalise quantité et chiffre d'affaires par mois et par produit.
-- Billet    : ATL-1

CREATE OR ALTER VIEW rpt.v_ventes_mensuelles
AS
SELECT
    p.code_produit,
    CONVERT(CHAR(7), v.date_vente, 126) AS annee_mois,
    SUM(v.quantite) AS quantite_totale,
    CONVERT(DECIMAL(18, 2), SUM(v.quantite * v.prix_unitaire)) AS montant_total
FROM dw.vente AS v
INNER JOIN dw.produit AS p
    ON v.id_produit = p.id_produit
GROUP BY
    CONVERT(CHAR(7), v.date_vente, 126),
    p.code_produit;
GO
