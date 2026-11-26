-- Test    : test_v_ventes_mensuelles.sql
-- Objet   : vérifie les totaux de rpt.v_ventes_mensuelles sur un jeu de données connu.
-- Méthode : on remplace dw.vente par quatre ventes connues (deux mois, deux produits);
--           tout s'exécute dans une transaction annulée.
-- Billet  : ATL-1
-- Échec   : THROW 50400+ avec un message explicite.

SET NOCOUNT ON;

BEGIN TRANSACTION;

DECLARE @id_client INT = (
    SELECT c.id_client FROM dw.client AS c
    WHERE c.code_client = N'CLI-001'
);
DECLARE @id_produit_1 INT = (
    SELECT p.id_produit FROM dw.produit AS p
    WHERE p.code_produit = N'PRD-001'
);
DECLARE @id_produit_2 INT = (
    SELECT p.id_produit FROM dw.produit AS p
    WHERE p.code_produit = N'PRD-002'
);

IF @id_client IS NULL OR @id_produit_1 IS NULL OR @id_produit_2 IS NULL
    THROW 50400, N'Préalable manquant : CLI-001, PRD-001 ou PRD-002 absent des données d''exemple.', 1;

DELETE FROM dw.vente;

INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
VALUES
(N'T-0001', '2024-01-03', @id_client, @id_produit_1, 2, 10.00),
(N'T-0002', '2024-01-31', @id_client, @id_produit_1, 3, 12.50),
(N'T-0003', '2024-01-15', @id_client, @id_produit_2, 1, 7.25),
(N'T-0004', '2024-02-01', @id_client, @id_produit_1, 4, 10.00);

IF (SELECT COUNT(*) FROM rpt.v_ventes_mensuelles) <> 3
    THROW 50401, N'La vue doit renvoyer une ligne par mois et par produit (3 attendues).', 1;

IF
    NOT EXISTS (
        SELECT 1
        FROM rpt.v_ventes_mensuelles AS r
        WHERE
            r.annee_mois = '2024-01'
            AND r.code_produit = N'PRD-001'
            AND r.quantite_totale = 5
            AND r.montant_total = 57.50
    )
    THROW 50402, N'Totaux de janvier 2024 pour PRD-001 incorrects (5 unités, 57,50 attendus).', 1;

IF
    NOT EXISTS (
        SELECT 1
        FROM rpt.v_ventes_mensuelles AS r
        WHERE
            r.annee_mois = '2024-01'
            AND r.code_produit = N'PRD-002'
            AND r.quantite_totale = 1
            AND r.montant_total = 7.25
    )
    THROW 50403, N'Totaux de janvier 2024 pour PRD-002 incorrects (1 unité, 7,25 attendus).', 1;

IF
    NOT EXISTS (
        SELECT 1
        FROM rpt.v_ventes_mensuelles AS r
        WHERE
            r.annee_mois = '2024-02'
            AND r.code_produit = N'PRD-001'
            AND r.quantite_totale = 4
            AND r.montant_total = 40.00
    )
    THROW 50404, N'Totaux de février 2024 pour PRD-001 incorrects (4 unités, 40,00 attendus).', 1;

ROLLBACK TRANSACTION;

PRINT N'[OK] test_v_ventes_mensuelles';
GO
