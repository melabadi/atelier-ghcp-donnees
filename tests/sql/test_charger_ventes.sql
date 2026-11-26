-- Test    : test_charger_ventes.sql
-- Objet   : vérifie un premier chargement correct par etl.usp_charger_ventes (une seule exécution).
-- Méthode : on vide dw.vente, on exécute la procédure une fois, on compare au contenu attendu de stg;
--           tout s'exécute dans une transaction annulée.
-- Échec   : THROW 50200+ avec un message explicite.

SET NOCOUNT ON;

BEGIN TRANSACTION;

DELETE FROM dw.vente;

-- Lignes attendues : convertibles et rattachées à un client et à un produit connus
DECLARE @nb_attendu INT;
DECLARE @montant_attendu DECIMAL(18, 2);

SELECT
    @nb_attendu = COUNT(*),
    @montant_attendu = SUM(TRY_CONVERT(INT, s.quantite) * TRY_CONVERT(DECIMAL(10, 2), s.prix_unitaire))
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

IF COALESCE(@nb_attendu, 0) = 0
    THROW 50200, N'Préalable manquant : stg.vente_brute ne contient aucune ligne chargeable.', 1;

DECLARE @nb_retourne INT;
EXEC etl.usp_charger_ventes @nb_lignes_inserees = @nb_retourne OUTPUT;

DECLARE @nb_obtenu INT;
DECLARE @montant_obtenu DECIMAL(18, 2);

SELECT
    @nb_obtenu = COUNT(*),
    @montant_obtenu = SUM(v.montant)
FROM dw.vente AS v;

IF @nb_obtenu <> @nb_attendu
    THROW 50201, N'Le nombre de lignes chargées dans dw.vente ne correspond pas aux lignes valides de stg.', 1;

IF @nb_retourne <> @nb_attendu
    THROW 50202, N'Le paramètre @nb_lignes_inserees ne correspond pas au nombre de lignes chargées.', 1;

IF @montant_obtenu <> @montant_attendu
    THROW 50203, N'Le montant total chargé ne correspond pas au montant attendu.', 1;

IF
    EXISTS (
        SELECT 1
        FROM dw.vente AS v
        INNER JOIN dw.client AS c
            ON v.id_client = c.id_client
        WHERE c.code_client = N'CLI-999'
    )
    THROW 50204, N'Une vente avec un client inconnu n''aurait pas dû être chargée.', 1;

ROLLBACK TRANSACTION;

PRINT N'[OK] test_charger_ventes';
GO
