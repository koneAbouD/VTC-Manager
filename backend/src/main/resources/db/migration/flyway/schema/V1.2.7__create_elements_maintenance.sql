CREATE TABLE IF NOT EXISTS elements_maintenance (
    id                    BIGSERIAL      PRIMARY KEY,
    catalogue_element_id  BIGINT,
    libelle               VARCHAR(255),
    montant               NUMERIC(19, 2) NOT NULL,
    detail_maintenance_id BIGINT         NOT NULL,
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP,
    CONSTRAINT fk_elements_maintenance_catalogue FOREIGN KEY (catalogue_element_id)  REFERENCES catalogue_elements_maintenance(id),
    CONSTRAINT fk_elements_maintenance_detail    FOREIGN KEY (detail_maintenance_id) REFERENCES details_maintenance(id)
);

CREATE INDEX IF NOT EXISTS idx_elements_maintenance_detail    ON elements_maintenance(detail_maintenance_id);
CREATE INDEX IF NOT EXISTS idx_elements_maintenance_catalogue ON elements_maintenance(catalogue_element_id);
