-- Module « Paramétrage des données de référence ».
-- Ajoute le drapeau d'activation logique (soft-disable) aux types de document,
-- pour les gérer via l'écran de paramétrage générique (comme les autres
-- référentiels). Défaut = actif.

ALTER TABLE types_document ADD COLUMN IF NOT EXISTS actif BOOLEAN NOT NULL DEFAULT TRUE;
