-- Jours fériés (Côte d'Ivoire). Table administrable, alimentée en mode hybride :
--   - fériés déterministes (fixes + chrétiens calculés) : source = AUTO ;
--   - fêtes musulmanes (calendrier lunaire, fixées par décret) : source = MANUEL.
-- Utilisée par la génération des recettes/cotisations : un jour férié suspend la
-- recette normale des véhicules dont la condition de travail prend en compte les
-- fériés (option feries_consideres), au même titre que le jour de salaire.
CREATE TABLE IF NOT EXISTS jours_feries (
    id         BIGSERIAL    PRIMARY KEY,
    date_ferie DATE         NOT NULL UNIQUE,
    libelle    VARCHAR(100) NOT NULL,
    type       VARCHAR(20)  NOT NULL,            -- FIXE | CHRETIEN | MUSULMAN | AUTRE
    annee      INTEGER      NOT NULL,
    source     VARCHAR(10)  NOT NULL DEFAULT 'MANUEL', -- AUTO | MANUEL
    created_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Accès par année (écran d'administration) et test d'appartenance par date (génération).
CREATE INDEX IF NOT EXISTS idx_jours_feries_annee ON jours_feries (annee);
