-- Maintenances : une intervention peut couvrir plusieurs types (vidange et
-- freinage au même passage au garage).
--   * maintenance_types porte tous les types de l'intervention, dans l'ordre
--     de saisie, sans doublon (garanti par l'application : une contrainte
--     d'unicité gênerait Hibernate quand il réordonne la liste ligne à ligne) ;
--   * maintenances.categorie_type_id reste le type principal (le premier) :
--     c'est lui qui catégorise la dépense ou la dette générée à la clôture.
-- Les éléments proposés à la saisie sont ceux des types retenus, plus les
-- éléments communs.
CREATE TABLE IF NOT EXISTS maintenance_types
(
    maintenance_id    BIGINT  NOT NULL,
    categorie_type_id BIGINT  NOT NULL,
    ordre             INTEGER NOT NULL,
    CONSTRAINT pk_maintenance_types PRIMARY KEY (maintenance_id, ordre),
    CONSTRAINT fk_maintenance_types_maintenance
        FOREIGN KEY (maintenance_id) REFERENCES maintenances (id) ON DELETE CASCADE,
    CONSTRAINT fk_maintenance_types_categorie
        FOREIGN KEY (categorie_type_id) REFERENCES categories_operation (id)
);

CREATE INDEX IF NOT EXISTS idx_maintenance_types_categorie
    ON maintenance_types (categorie_type_id);

-- Reprise : chaque maintenance typée garde son type comme unique type.
INSERT INTO maintenance_types (maintenance_id, categorie_type_id, ordre)
SELECT id, categorie_type_id, 0
FROM maintenances
WHERE categorie_type_id IS NOT NULL
ON CONFLICT DO NOTHING;
