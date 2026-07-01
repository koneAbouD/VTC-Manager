-- Lien optionnel opération financière → maintenance d'origine.
-- Renseigné lorsque l'opération (dépense) est générée par la complétion d'une
-- maintenance. Permet, à l'annulation de l'opération, de rouvrir la maintenance
-- (retour à l'état antérieur à la complétion).
ALTER TABLE operations_financieres
    ADD COLUMN IF NOT EXISTS maintenance_id BIGINT,
    ADD CONSTRAINT fk_operations_financieres_maintenance
        FOREIGN KEY (maintenance_id) REFERENCES maintenances(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_operations_financieres_maintenance
    ON operations_financieres(maintenance_id);
