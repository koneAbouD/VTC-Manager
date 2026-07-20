-- Module « Paramétrage des données de référence » — Lot 1 (suite).
-- Ajoute le drapeau d'activation logique aux modèles et statuts de véhicule.

ALTER TABLE modeles          ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE statuts_vehicule ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
