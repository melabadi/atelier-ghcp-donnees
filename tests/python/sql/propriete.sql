-- Objet : vérifier la propriété de la base jetable avant toute écriture Python.
SELECT CONVERT(NVARCHAR(128), value)
FROM sys.extended_properties
WHERE class = 0 AND name = N'atelier_tests';
