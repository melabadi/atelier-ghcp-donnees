-- Migration : V2__creer_stg_vente_brute.sql
-- Objet     : table de transit des ventes, telle qu'extraite de la source.
-- Les types sont volontairement larges (texte) : la conversion se fait au chargement.

CREATE TABLE stg.vente_brute (
    id_ligne INT IDENTITY (1, 1) NOT NULL,
    numero_vente NVARCHAR(50) NULL,
    date_vente NVARCHAR(50) NULL,
    code_client NVARCHAR(50) NULL,
    code_produit NVARCHAR(50) NULL,
    quantite NVARCHAR(50) NULL,
    prix_unitaire NVARCHAR(50) NULL,
    date_extraction DATETIME2(0) NOT NULL
    CONSTRAINT df_vente_brute_date_extraction DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_vente_brute PRIMARY KEY CLUSTERED (id_ligne)
);
GO
