-- Éléments de maintenance : montant par défaut (pré-remplissage à la saisie)
-- et image d'illustration (objectName du stockage MinIO/S3).
ALTER TABLE catalogue_elements_maintenance
    ADD COLUMN montant_defaut NUMERIC(19, 2),
    ADD COLUMN image          VARCHAR(512);
