-- Test    : test_contraintes_vente.sql
-- Objet   : vérifie que les contraintes de dw.vente refusent les valeurs invalides.
-- Méthode : chaque insertion invalide doit échouer; tout s'exécute dans une transaction annulée.
-- Échec   : THROW 50000+ avec un message explicite.

SET NOCOUNT ON;
SET XACT_ABORT OFF;

BEGIN TRANSACTION;

DECLARE @id_client INT = (SELECT MIN(c.id_client) FROM dw.client AS c);
DECLARE @id_produit INT = (SELECT MIN(p.id_produit) FROM dw.produit AS p);
DECLARE @erreur INT;

IF @id_client IS NULL OR @id_produit IS NULL
    THROW 50100, N'Préalable manquant : dw.client et dw.produit doivent contenir des données.', 1;

-- 1. Une vente valide est acceptée
INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
VALUES (N'T-VALIDE', '2024-01-01', @id_client, @id_produit, 1, 10.00);

IF
    NOT EXISTS (
        SELECT 1 FROM dw.vente AS v
        WHERE v.numero_vente = N'T-VALIDE' AND v.montant = 10.00
    )
    THROW 50101, N'Une vente valide aurait dû être insérée avec un montant de 10.00.', 1;

-- 2. Quantité nulle refusée (ck_vente_quantite)
SET @erreur = 0;
BEGIN TRY
    INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
    VALUES (N'T-QTE-0', '2024-01-01', @id_client, @id_produit, 0, 10.00);
END TRY
BEGIN CATCH
    SET @erreur = ERROR_NUMBER();
END CATCH;

IF @erreur <> 547
    THROW 50102, N'Une quantité de 0 aurait dû être refusée par ck_vente_quantite.', 1;

-- 3. Prix unitaire négatif refusé (ck_vente_prix_unitaire)
SET @erreur = 0;
BEGIN TRY
    INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
    VALUES (N'T-PRIX-NEG', '2024-01-01', @id_client, @id_produit, 1, -1.00);
END TRY
BEGIN CATCH
    SET @erreur = ERROR_NUMBER();
END CATCH;

IF @erreur <> 547
    THROW 50103, N'Un prix unitaire négatif aurait dû être refusé par ck_vente_prix_unitaire.', 1;

-- 4. Client inexistant refusé (fk_vente_client)
SET @erreur = 0;
BEGIN TRY
    INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
    VALUES (N'T-FK-CLIENT', '2024-01-01', -1, @id_produit, 1, 10.00);
END TRY
BEGIN CATCH
    SET @erreur = ERROR_NUMBER();
END CATCH;

IF @erreur <> 547
    THROW 50104, N'Un client inexistant aurait dû être refusé par fk_vente_client.', 1;

-- 5. Produit inexistant refusé (fk_vente_produit)
SET @erreur = 0;
BEGIN TRY
    INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
    VALUES (N'T-FK-PRODUIT', '2024-01-01', @id_client, -1, 1, 10.00);
END TRY
BEGIN CATCH
    SET @erreur = ERROR_NUMBER();
END CATCH;

IF @erreur <> 547
    THROW 50105, N'Un produit inexistant aurait dû être refusé par fk_vente_produit.', 1;

-- 6. Numéro de vente obligatoire (NOT NULL)
SET @erreur = 0;
BEGIN TRY
    INSERT INTO dw.vente (numero_vente, date_vente, id_client, id_produit, quantite, prix_unitaire)
    VALUES (NULL, '2024-01-01', @id_client, @id_produit, 1, 10.00);
END TRY
BEGIN CATCH
    SET @erreur = ERROR_NUMBER();
END CATCH;

IF @erreur <> 515
    THROW 50106, N'Un numéro de vente NULL aurait dû être refusé.', 1;

ROLLBACK TRANSACTION;

PRINT N'[OK] test_contraintes_vente';
GO
