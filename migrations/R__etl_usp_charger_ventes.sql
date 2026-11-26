-- Migration : R__etl_usp_charger_ventes.sql (répétable)
-- Objet     : charge les ventes de stg.vente_brute vers dw.vente.
-- Règles    : conversion des types texte, résolution des clés client et produit;
--             les lignes non convertibles ou sans client/produit connu sont ignorées.
-- Retour    : nombre de lignes insérées (paramètre de sortie @nb_lignes_inserees).

CREATE OR ALTER PROCEDURE etl.usp_charger_ventes
    @nb_lignes_inserees INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dw.vente (
            numero_vente,
            date_vente,
            id_client,
            id_produit,
            quantite,
            prix_unitaire
        )
        SELECT
            s.numero_vente,
            TRY_CONVERT(DATE, s.date_vente, 23) AS date_vente,
            c.id_client,
            p.id_produit,
            TRY_CONVERT(INT, s.quantite) AS quantite,
            TRY_CONVERT(DECIMAL(10, 2), s.prix_unitaire) AS prix_unitaire
        FROM stg.vente_brute AS s
        INNER JOIN dw.client AS c
            ON s.code_client = c.code_client
        INNER JOIN dw.produit AS p
            ON s.code_produit = p.code_produit
        WHERE
            s.numero_vente IS NOT NULL
            AND TRY_CONVERT(DATE, s.date_vente, 23) IS NOT NULL
            AND TRY_CONVERT(INT, s.quantite) IS NOT NULL
            AND TRY_CONVERT(DECIMAL(10, 2), s.prix_unitaire) IS NOT NULL;

        SET @nb_lignes_inserees = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
