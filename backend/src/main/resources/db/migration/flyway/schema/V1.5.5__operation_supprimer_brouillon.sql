-- Le statut BROUILLON est supprimé : les opérations manuelles sont désormais
-- créées directement ENCAISSE (revenu) / PAYE (dépense). Migration des
-- éventuelles opérations encore en brouillon.
UPDATE operations_financieres
SET statut = CASE
        WHEN type_operation = 'REVENU' THEN 'ENCAISSE'
        ELSE 'PAYE'
    END
WHERE statut = 'BROUILLON';
