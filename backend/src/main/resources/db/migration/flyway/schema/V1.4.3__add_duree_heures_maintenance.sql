ALTER TABLE maintenances
    ADD COLUMN IF NOT EXISTS duree_heures INT;

ALTER TABLE details_maintenance
    DROP COLUMN IF EXISTS duree_maintenance;
