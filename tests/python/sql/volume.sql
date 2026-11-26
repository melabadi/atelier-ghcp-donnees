-- Objet : créer un volume déterministe sans dépendre des catalogues système.
DECLARE @nb INT = ?;
DELETE FROM stg.vente_brute;
WITH chiffre AS (
    SELECT n FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS d(n)
),

nombres AS (
    SELECT TOP (@nb) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM chiffre AS a
    CROSS JOIN chiffre AS b
    CROSS JOIN chiffre AS c
    CROSS JOIN chiffre AS d
    CROSS JOIN chiffre AS e
    CROSS JOIN chiffre AS f
)

INSERT INTO stg.vente_brute (
    numero_vente, date_vente, code_client, code_produit, quantite, prix_unitaire
)
SELECT
    N'PY-' + CONVERT(NVARCHAR(12), n) AS numero_vente,
    N'2024-01-03' AS date_vente,
    N'CLI-001' AS code_client,
    N'PRD-001' AS code_produit,
    N'2' AS quantite,
    N'18.50' AS prix_unitaire
FROM nombres;
UPDATE STATISTICS stg.vente_brute WITH FULLSCAN;
