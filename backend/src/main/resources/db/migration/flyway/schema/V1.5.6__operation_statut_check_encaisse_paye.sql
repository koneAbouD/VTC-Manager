-- La contrainte CHECK du statut d'opération n'autorisait que les anciennes
-- valeurs (BROUILLON / VALIDEE / ANNULEE). Le modèle utilise désormais
-- ENCAISSE / PAYE / ANNULEE → on remplace la contrainte.

-- 1) Retirer l'ancienne contrainte (sinon la conversion ci-dessous serait bloquée).
ALTER TABLE operations_financieres
    DROP CONSTRAINT IF EXISTS chk_operations_financieres_statut;

-- 2) Filet : convertir d'éventuels statuts hérités encore présents.
UPDATE operations_financieres
SET statut = CASE WHEN type_operation = 'REVENU' THEN 'ENCAISSE' ELSE 'PAYE' END
WHERE statut IN ('BROUILLON', 'VALIDEE');

-- 3) Recréer la contrainte avec les valeurs courantes.
ALTER TABLE operations_financieres
    ADD CONSTRAINT chk_operations_financieres_statut
    CHECK (statut IN ('ENCAISSE', 'PAYE', 'ANNULEE'));
