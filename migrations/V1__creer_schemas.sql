-- Migration : V1__creer_schemas.sql
-- Objet     : crée les schémas du projet Brûlerie Démo.
--   stg : données brutes extraites des sources
--   dw  : modèle dimensionnel
--   rpt : vues de rapport
--   etl : procédures de chargement
-- CREATE SCHEMA doit être la seule instruction de son lot : un GO par schéma.

CREATE SCHEMA stg AUTHORIZATION dbo;
GO

CREATE SCHEMA dw AUTHORIZATION dbo;
GO

CREATE SCHEMA rpt AUTHORIZATION dbo;
GO

CREATE SCHEMA etl AUTHORIZATION dbo;
GO
