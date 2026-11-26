-- Migration : R__donnees_exemple.sql (répétable, environnements dev et ci seulement)
-- Objet     : données fictives et déterministes de la Brûlerie Démo.
-- Mécanisme : migration répétable dans un emplacement Flyway séparé (donnees-exemple/),
--             ajouté aux « locations » des environnements dev et ci dans flyway.toml.
--             Idempotente : MERGE pour les dimensions, remplacement complet pour stg.
-- dw.vente n'est pas alimentée ici : c'est le rôle de etl.usp_charger_ventes.

MERGE dw.client AS cible
USING (
    VALUES
    (N'CLI-001', N'Café Fictif Aurore', N'Ville A'),
    (N'CLI-002', N'Bistro Démo Boréal', N'Ville B'),
    (N'CLI-003', N'Épicerie Exemple Cèdre', N'Ville A'),
    (N'CLI-004', N'Comptoir Test Érable', N'Ville C'),
    (N'CLI-005', N'Restaurant Fictif Flocon', N'Ville B'),
    (N'CLI-006', N'Kiosque Démo Grésil', N'Ville D'),
    (N'CLI-007', N'Traiteur Exemple Huard', N'Ville C'),
    (N'CLI-008', N'Café Test Iris', N'Ville D')
) AS donnees(code_client, nom_client, ville)
    ON cible.code_client = donnees.code_client
WHEN MATCHED
    THEN
    UPDATE
        SET
            cible.nom_client = donnees.nom_client,
            cible.ville = donnees.ville
WHEN NOT MATCHED BY TARGET
    THEN
    INSERT (code_client, nom_client, ville)
    VALUES (donnees.code_client, donnees.nom_client, donnees.ville);
GO

MERGE dw.produit AS cible
USING (
    VALUES
    (N'PRD-001', N'Mélange maison', N'Assemblage', 18.50),
    (N'PRD-002', N'Espresso corsé', N'Assemblage', 21.00),
    (N'PRD-003', N'Origine unique A', N'Région fictive A', 24.75),
    (N'PRD-004', N'Origine unique B', N'Région fictive B', 26.25),
    (N'PRD-005', N'Décaféiné doux', N'Assemblage', 19.95),
    (N'PRD-006', N'Torréfaction claire', N'Région fictive C', 23.40)
) AS donnees(code_produit, nom_produit, origine, prix_catalogue)
    ON cible.code_produit = donnees.code_produit
WHEN MATCHED
    THEN
    UPDATE
        SET
            cible.nom_produit = donnees.nom_produit,
            cible.origine = donnees.origine,
            cible.prix_catalogue = donnees.prix_catalogue
WHEN NOT MATCHED BY TARGET
    THEN
    INSERT (code_produit, nom_produit, origine, prix_catalogue)
    VALUES (donnees.code_produit, donnees.nom_produit, donnees.origine, donnees.prix_catalogue);
GO

DELETE FROM stg.vente_brute;
GO

INSERT INTO stg.vente_brute (
    numero_vente, date_vente, code_client, code_produit, quantite, prix_unitaire
)
VALUES
(N'V-0001', N'2024-01-03', N'CLI-001', N'PRD-001', N'12', N'18.50'),
(N'V-0002', N'2024-01-04', N'CLI-002', N'PRD-002', N'6', N'21.00'),
(N'V-0003', N'2024-01-07', N'CLI-003', N'PRD-003', N'4', N'24.75'),
(N'V-0004', N'2024-01-09', N'CLI-004', N'PRD-001', N'10', N'18.50'),
(N'V-0005', N'2024-01-12', N'CLI-005', N'PRD-005', N'3', N'19.95'),
(N'V-0006', N'2024-01-15', N'CLI-006', N'PRD-006', N'8', N'23.40'),
(N'V-0007', N'2024-01-18', N'CLI-007', N'PRD-004', N'5', N'26.25'),
(N'V-0008', N'2024-01-22', N'CLI-008', N'PRD-002', N'9', N'21.00'),
(N'V-0009', N'2024-01-25', N'CLI-001', N'PRD-003', N'2', N'24.75'),
(N'V-0010', N'2024-01-29', N'CLI-002', N'PRD-001', N'15', N'18.50'),
(N'V-0011', N'2024-02-01', N'CLI-003', N'PRD-005', N'7', N'19.95'),
(N'V-0012', N'2024-02-05', N'CLI-004', N'PRD-006', N'4', N'23.40'),
(N'V-0013', N'2024-02-08', N'CLI-005', N'PRD-002', N'11', N'21.00'),
(N'V-0014', N'2024-02-12', N'CLI-006', N'PRD-004', N'3', N'26.25'),
(N'V-0015', N'2024-02-15', N'CLI-007', N'PRD-001', N'20', N'18.50'),
(N'V-0016', N'2024-02-19', N'CLI-008', N'PRD-003', N'6', N'24.75'),
(N'V-0017', N'2024-02-22', N'CLI-001', N'PRD-005', N'5', N'19.95'),
(N'V-0018', N'2024-02-26', N'CLI-002', N'PRD-006', N'9', N'23.40'),
(N'V-0019', N'2024-03-01', N'CLI-003', N'PRD-002', N'8', N'21.00'),
(N'V-0020', N'2024-03-05', N'CLI-004', N'PRD-004', N'2', N'26.25'),
(N'V-0021', N'2024-03-08', N'CLI-005', N'PRD-001', N'14', N'18.50'),
(N'V-0022', N'2024-03-12', N'CLI-006', N'PRD-003', N'7', N'24.75'),
(N'V-0023', N'2024-03-15', N'CLI-007', N'PRD-005', N'4', N'19.95'),
(N'V-0024', N'2024-03-19', N'CLI-008', N'PRD-006', N'10', N'23.40'),
(N'V-0025', N'2024-03-22', N'CLI-001', N'PRD-002', N'3', N'21.00'),
(N'V-0026', N'2024-03-26', N'CLI-002', N'PRD-004', N'6', N'26.25'),
(N'V-0027', N'2024-03-29', N'CLI-003', N'PRD-001', N'9', N'18.50'),
(N'V-0028', N'2024-03-30', N'CLI-004', N'PRD-003', N'5', N'24.75'),
(N'V-0029', N'2024-03-30', N'CLI-999', N'PRD-001', N'4', N'18.50'),
(N'V-0030', N'date-invalide', N'CLI-005', N'PRD-002', N'2', N'21.00');
GO
