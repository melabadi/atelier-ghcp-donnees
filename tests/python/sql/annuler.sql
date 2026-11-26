-- Objet : annuler le test même si la procédure a déjà annulé sa transaction.
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
