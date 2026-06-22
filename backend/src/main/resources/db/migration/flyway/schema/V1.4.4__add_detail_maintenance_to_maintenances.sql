ALTER TABLE maintenances
    ADD COLUMN IF NOT EXISTS detail_maintenance_id BIGINT,
    ADD CONSTRAINT fk_maintenances_detail_maintenance
        FOREIGN KEY (detail_maintenance_id) REFERENCES details_maintenance(id);

CREATE INDEX IF NOT EXISTS idx_maintenances_detail_maintenance
    ON maintenances(detail_maintenance_id);
