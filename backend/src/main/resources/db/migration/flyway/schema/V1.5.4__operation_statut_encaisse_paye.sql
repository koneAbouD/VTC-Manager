-- Le statut "VALIDEE" générique est remplacé par deux statuts métier :
--   REVENU  -> ENCAISSE
--   DEPENSE -> PAYE

-- La contrainte CHECK d'origine (BROUILLON/VALIDEE/ANNULEE) rejetterait les
-- nouvelles valeurs : on la retire avant la conversion. Elle est recréée avec
-- les valeurs courantes en V1.5.6.
ALTER TABLE operations_financieres
    DROP CONSTRAINT IF EXISTS chk_operations_financieres_statut;

-- Migration des opérations existantes.
UPDATE operations_financieres
SET statut = CASE
        WHEN type_operation = 'REVENU' THEN 'ENCAISSE'
        ELSE 'PAYE'
    END
WHERE statut = 'VALIDEE';
