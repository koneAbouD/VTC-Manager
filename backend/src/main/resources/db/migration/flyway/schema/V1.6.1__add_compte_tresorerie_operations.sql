ALTER TABLE operations_financieres
    ADD COLUMN IF NOT EXISTS compte_tresorerie_id BIGINT REFERENCES comptes_tresorerie(id);

-- Backfill : rattache les opérations existantes au compte par défaut
-- correspondant à leur mode de paiement.
UPDATE operations_financieres o
SET compte_tresorerie_id = c.id
FROM comptes_tresorerie c
WHERE o.compte_tresorerie_id IS NULL
  AND c.par_defaut
  AND ((o.mode_paiement = 'ESPECES'      AND c.type = 'CAISSE')
    OR (o.mode_paiement = 'MOBILE_MONEY' AND c.type = 'MOBILE_MONEY'));

-- Index de calcul des soldes : somme des montants par compte et statut.
CREATE INDEX IF NOT EXISTS idx_operations_financieres_compte_statut
    ON operations_financieres (compte_tresorerie_id, statut);
