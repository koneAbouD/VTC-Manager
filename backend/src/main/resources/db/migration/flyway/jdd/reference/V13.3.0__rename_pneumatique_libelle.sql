-- Renomme le libellé de la catégorie « Pneumatiques » en « Pneumatique »
-- (singulier). Le code reste inchangé (PNEUMATIQUE).
UPDATE categories_operation
SET libelle = 'Pneumatique'
WHERE code = 'PNEUMATIQUE';
