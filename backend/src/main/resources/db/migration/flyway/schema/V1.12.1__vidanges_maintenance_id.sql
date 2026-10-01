-- Vidange enregistrée à la clôture d'une maintenance « Vidange » : le lien permet
-- de la retirer si la complétion est défaite (annulation de la dépense, la
-- maintenance repasse planifiée), et garantit qu'une maintenance n'en produit
-- qu'une. Les vidanges saisies à la main n'en portent pas.
ALTER TABLE vidanges
    ADD COLUMN IF NOT EXISTS maintenance_id BIGINT REFERENCES maintenances (id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uk_vidanges_maintenance
    ON vidanges (maintenance_id) WHERE maintenance_id IS NOT NULL;
