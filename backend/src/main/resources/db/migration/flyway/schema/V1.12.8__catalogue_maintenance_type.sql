-- Éléments de maintenance : type de maintenance (facultatif).
--   * sans type → élément commun, proposé quel que soit le type de
--                 l'intervention (main d'œuvre, pièce utilisée partout) ;
--   * avec type → proposé pour les seules interventions de ce type.
-- Le type est une catégorie d'opération de la sous-catégorie « Maintenances » ;
-- cette appartenance est contrôlée par l'application.
--
-- Le renseignement des éléments existants est fait par la migration de données
-- V13.8.0 (jdd/reference) : sur une base neuve, elle passe après l'insertion du
-- catalogue de référence (V11.0.0), que ce script précède.
ALTER TABLE catalogue_elements_maintenance
    ADD COLUMN IF NOT EXISTS categorie_type_id BIGINT;

ALTER TABLE catalogue_elements_maintenance
    DROP CONSTRAINT IF EXISTS fk_catalogue_elements_maintenance_categorie_type;

ALTER TABLE catalogue_elements_maintenance
    ADD CONSTRAINT fk_catalogue_elements_maintenance_categorie_type
        FOREIGN KEY (categorie_type_id) REFERENCES categories_operation (id);

CREATE INDEX IF NOT EXISTS idx_catalogue_elements_maintenance_categorie_type
    ON catalogue_elements_maintenance (categorie_type_id);
