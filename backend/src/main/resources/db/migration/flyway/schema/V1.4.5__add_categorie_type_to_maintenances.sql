ALTER TABLE maintenances
    ADD COLUMN IF NOT EXISTS categorie_type_id BIGINT,
    ADD CONSTRAINT fk_maintenances_categorie_type
        FOREIGN KEY (categorie_type_id) REFERENCES categories_operation(id);

CREATE INDEX IF NOT EXISTS idx_maintenances_categorie_type
    ON maintenances(categorie_type_id);
