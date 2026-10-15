-- Éléments de maintenance : marque et modèle de véhicule (facultatifs).
--   * sans marque         → élément générique, proposé pour tous les véhicules ;
--   * marque sans modèle  → proposé pour tous les modèles de cette marque ;
--   * marque + modèle     → proposé pour ce seul modèle.
ALTER TABLE catalogue_elements_maintenance
    ADD COLUMN marque_id BIGINT,
    ADD COLUMN modele_id BIGINT,
    ADD CONSTRAINT fk_catalogue_elements_maintenance_marque
        FOREIGN KEY (marque_id) REFERENCES marques (id),
    ADD CONSTRAINT fk_catalogue_elements_maintenance_modele
        FOREIGN KEY (modele_id) REFERENCES modeles (id),
    -- Un modèle sans sa marque n'aurait pas de sens : la marque est déduite du
    -- modèle côté serveur, la base se contente d'interdire l'incohérence.
    ADD CONSTRAINT ck_catalogue_elements_maintenance_modele_marque
        CHECK (modele_id IS NULL OR marque_id IS NOT NULL);

-- Le libellé n'est plus unique à lui seul : « Plaquettes de frein » peut
-- exister pour plusieurs modèles. L'unicité porte sur le triplet, les NULL
-- (élément générique) étant ramenés à 0 pour rester comparables.
ALTER TABLE catalogue_elements_maintenance
    DROP CONSTRAINT IF EXISTS uk_catalogue_elements_maintenance_libelle;

CREATE UNIQUE INDEX uk_catalogue_elements_maintenance_libelle_vehicule
    ON catalogue_elements_maintenance (libelle, COALESCE(marque_id, 0), COALESCE(modele_id, 0));

CREATE INDEX idx_catalogue_elements_maintenance_marque ON catalogue_elements_maintenance (marque_id);
CREATE INDEX idx_catalogue_elements_maintenance_modele ON catalogue_elements_maintenance (modele_id);
