-- Motif d'annulation obligatoire (saisi par l'utilisateur) sur les lignes
-- recette / cotisation / pénalité. Conservé pour l'audit et l'affichage.
ALTER TABLE lignes_recette    ADD COLUMN IF NOT EXISTS motif_annulation VARCHAR(500);
ALTER TABLE lignes_cotisation ADD COLUMN IF NOT EXISTS motif_annulation VARCHAR(500);
ALTER TABLE lignes_penalite   ADD COLUMN IF NOT EXISTS motif_annulation VARCHAR(500);
