-- Le statut "VALIDEE" générique est remplacé par deux statuts métier :
--   REVENU  -> ENCAISSE
--   DEPENSE -> PAYE
-- Migration des opérations existantes.
UPDATE operations_financieres
SET statut = CASE
        WHEN type_operation = 'REVENU' THEN 'ENCAISSE'
        ELSE 'PAYE'
    END
WHERE statut = 'VALIDEE';
