-- Module « Paramétrage des données de référence » — Lot 1.
-- Ajoute un drapeau d'activation logique (soft-disable) aux référentiels rendus
-- éditables. Permet de désactiver une valeur sans la supprimer (donc sans casser
-- les données transactionnelles qui la référencent). Défaut = actif.
--
-- Périmètre livré : types de véhicule, types d'activité, marques.
-- (catalogue_elements_maintenance possède déjà sa colonne « actif ».)
-- Modèles et statuts de véhicule sont suspendus pour une version ultérieure.

ALTER TABLE types_vehicule ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE types_activite ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE marques        ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
