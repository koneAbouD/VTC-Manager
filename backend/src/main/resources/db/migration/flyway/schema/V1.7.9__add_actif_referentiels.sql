-- Module « Paramétrage des données de référence » — Lot 1 (Socle).
-- Ajoute un drapeau d'activation logique (soft-disable) aux référentiels de
-- Tier A. Permet de désactiver une valeur sans la supprimer (donc sans casser
-- les données transactionnelles qui la référencent). Défaut = actif.

ALTER TABLE types_vehicule   ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE types_activite   ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE marques          ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE modeles          ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE statuts_vehicule ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
