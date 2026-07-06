-- Prise en compte des jours fériés, configurable par véhicule (miroir du jour de salaire).
-- condition_travail : option d'activation + montant de recette dû le jour férié (recette fixe).
ALTER TABLE condition_travail
    ADD COLUMN IF NOT EXISTS feries_consideres  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS montant_jour_ferie NUMERIC(15, 2);

-- Programme de travail : drapeau propagé depuis la condition, consulté par la génération.
ALTER TABLE vehicule_programmes
    ADD COLUMN IF NOT EXISTS feries_actif BOOLEAN NOT NULL DEFAULT FALSE;

-- Configuration recette : montant dû le jour férié, propagé depuis la condition.
ALTER TABLE vehicule_configurations_recette
    ADD COLUMN IF NOT EXISTS montant_jour_ferie NUMERIC(19, 2);
