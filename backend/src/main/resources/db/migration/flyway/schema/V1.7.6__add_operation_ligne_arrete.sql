-- Trace l'opération financière de compensation créée pour chaque ligne DEBIT
-- (recette/pénalité/contravention éteinte). Indispensable à l'annulation d'un
-- arrêté : on retrouve ainsi l'encaissement/opération à contre-passer.
ALTER TABLE lignes_arrete
    ADD COLUMN IF NOT EXISTS operation_id BIGINT;
