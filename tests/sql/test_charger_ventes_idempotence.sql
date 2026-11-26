-- Test    : test_charger_ventes_idempotence.sql
-- Objet   : non-régression ATL-2; deux appels successifs de etl.usp_charger_ventes
--           donnent le même contenu de dw.vente qu'un seul appel.
-- Méthode : on vide dw.vente, on exécute la procédure deux fois et on compare;
--           tout s'exécute dans une transaction annulée.
-- Billet  : ATL-2
-- Échec   : THROW 50500+ avec un message explicite.

SET NOCOUNT ON;

BEGIN TRANSACTION;

DELETE FROM dw.vente;

DECLARE @nb_premier_appel INT;
DECLARE @nb_deuxieme_appel INT;

EXEC etl.usp_charger_ventes @nb_lignes_inserees = @nb_premier_appel OUTPUT;

DECLARE @nb_apres_premier INT;
DECLARE @montant_apres_premier DECIMAL(18, 2);

SELECT
    @nb_apres_premier = COUNT(*),
    @montant_apres_premier = SUM(v.montant)
FROM dw.vente AS v;

IF COALESCE(@nb_premier_appel, 0) = 0
    THROW 50500, N'Préalable manquant : le premier appel n''a chargé aucune vente.', 1;

EXEC etl.usp_charger_ventes @nb_lignes_inserees = @nb_deuxieme_appel OUTPUT;

DECLARE @nb_apres_deuxieme INT;
DECLARE @montant_apres_deuxieme DECIMAL(18, 2);

SELECT
    @nb_apres_deuxieme = COUNT(*),
    @montant_apres_deuxieme = SUM(v.montant)
FROM dw.vente AS v;

IF @nb_deuxieme_appel <> 0
    THROW 50501, N'Le deuxième appel doit renvoyer @nb_lignes_inserees = 0.', 1;

IF @nb_apres_deuxieme <> @nb_apres_premier
    THROW 50502, N'Le deuxième appel a modifié le nombre de lignes de dw.vente (doublons).', 1;

IF @montant_apres_deuxieme <> @montant_apres_premier
    THROW 50503, N'Le deuxième appel a modifié le montant total de dw.vente.', 1;

IF
    EXISTS (
        SELECT v.numero_vente
        FROM dw.vente AS v
        GROUP BY v.numero_vente
        HAVING COUNT(*) > 1
    )
    THROW 50504, N'Un numero_vente apparaît plus d''une fois dans dw.vente.', 1;

ROLLBACK TRANSACTION;

PRINT N'[OK] test_charger_ventes_idempotence';
GO
