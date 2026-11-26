-- Migration : V3__creer_tables_dw.sql
-- Objet     : tables du modèle dw (client, produit, vente), clés, contraintes et index de base.

CREATE TABLE dw.client (
    id_client INT IDENTITY (1, 1) NOT NULL,
    code_client NVARCHAR(20) NOT NULL,
    nom_client NVARCHAR(100) NOT NULL,
    ville NVARCHAR(100) NULL,
    date_creation DATETIME2(0) NOT NULL
    CONSTRAINT df_client_date_creation DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_client PRIMARY KEY CLUSTERED (id_client),
    CONSTRAINT uq_client_code_client UNIQUE (code_client)
);
GO

CREATE TABLE dw.produit (
    id_produit INT IDENTITY (1, 1) NOT NULL,
    code_produit NVARCHAR(20) NOT NULL,
    nom_produit NVARCHAR(100) NOT NULL,
    origine NVARCHAR(50) NULL,
    prix_catalogue DECIMAL(10, 2) NOT NULL,
    CONSTRAINT pk_produit PRIMARY KEY CLUSTERED (id_produit),
    CONSTRAINT uq_produit_code_produit UNIQUE (code_produit),
    CONSTRAINT ck_produit_prix_catalogue CHECK (prix_catalogue >= 0)
);
GO

CREATE TABLE dw.vente (
    id_vente BIGINT IDENTITY (1, 1) NOT NULL,
    numero_vente NVARCHAR(20) NOT NULL,
    date_vente DATE NOT NULL,
    id_client INT NOT NULL,
    id_produit INT NOT NULL,
    quantite INT NOT NULL,
    prix_unitaire DECIMAL(10, 2) NOT NULL,
    montant AS (quantite * prix_unitaire) PERSISTED,
    date_chargement DATETIME2(0) NOT NULL
    CONSTRAINT df_vente_date_chargement DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_vente PRIMARY KEY CLUSTERED (id_vente),
    CONSTRAINT fk_vente_client FOREIGN KEY (id_client) REFERENCES dw.client (id_client),
    CONSTRAINT fk_vente_produit FOREIGN KEY (id_produit) REFERENCES dw.produit (id_produit),
    CONSTRAINT ck_vente_quantite CHECK (quantite > 0),
    CONSTRAINT ck_vente_prix_unitaire CHECK (prix_unitaire >= 0)
);
GO

CREATE NONCLUSTERED INDEX ix_vente_date_vente ON dw.vente (date_vente);
GO

CREATE NONCLUSTERED INDEX ix_vente_id_client ON dw.vente (id_client);
GO

CREATE NONCLUSTERED INDEX ix_vente_id_produit ON dw.vente (id_produit);
GO
