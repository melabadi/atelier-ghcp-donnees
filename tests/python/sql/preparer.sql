-- Objet : isoler chaque test dans une transaction externe annulée.
SET NOCOUNT ON;
BEGIN TRANSACTION;
DELETE FROM dw.vente;
DELETE FROM stg.vente_brute;
INSERT INTO stg.vente_brute (
    numero_vente, date_vente, code_client, code_produit, quantite, prix_unitaire
)
VALUES
(N'PY-001', N'2024-01-03', N'CLI-001', N'PRD-001', N'2', N'18.50'),
(N'PY-002', N'2024-02-05', N'CLI-002', N'PRD-002', N'3', N'21.00');
