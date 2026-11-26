-- Objet : appeler la procédure et récupérer son paramètre OUTPUT.
DECLARE @nb INT;
EXEC etl.usp_charger_ventes @nb_lignes_inserees = @nb OUTPUT;
SELECT @nb AS nb;
