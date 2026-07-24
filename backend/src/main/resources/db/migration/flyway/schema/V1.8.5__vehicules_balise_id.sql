-- Le véhicule référence désormais une balise du référentiel (balise_id) au lieu
-- de porter directement le n° de téléphone et l'identifiant de la balise.
-- Décision produit : repartir de zéro (anciennes colonnes abandonnées, balises
-- ressaisies dans Paramètres).
ALTER TABLE vehicules
    ADD COLUMN IF NOT EXISTS balise_id BIGINT;

ALTER TABLE vehicules
    DROP CONSTRAINT IF EXISTS fk_vehicules_balise;

ALTER TABLE vehicules
    ADD CONSTRAINT fk_vehicules_balise
        FOREIGN KEY (balise_id) REFERENCES balises(id);

CREATE INDEX IF NOT EXISTS idx_vehicules_balise ON vehicules(balise_id);

ALTER TABLE vehicules DROP COLUMN IF EXISTS numero_telephone_balise;
ALTER TABLE vehicules DROP COLUMN IF EXISTS identifiant_balise;
