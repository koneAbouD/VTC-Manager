-- Date de reversement à l'État, distincte de la date de paiement du chauffeur.
--
-- Jusqu'ici, `reverser()` écrasait `date_paiement` avec la date du reversement :
-- l'encaissement auprès du chauffeur et le versement à l'État partageaient une
-- seule colonne. Impossible dès lors de savoir, à une date passée, ce que
-- l'entreprise détenait encore pour le compte de l'État — la dette du bilan ne
-- pouvait pas être arrêtée à une date.

ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS date_reversement DATE;

COMMENT ON COLUMN contraventions.date_reversement IS
    'Jour où la somme a été reversée à l''État ; NULL tant qu''elle est détenue.';

-- Reprise de l'existant : on retrouve la date sur l'écriture de reversement
-- (même chauffeur, même date d'infraction en date de référence). À défaut,
-- la date de paiement enregistrée fait foi — c'est elle que `reverser()`
-- écrasait avec le jour du reversement.
UPDATE contraventions c
SET date_reversement = COALESCE(
        (SELECT MIN(o.date_operation)
           FROM operations_financieres o
           JOIN categories_operation cat ON cat.id = o.categorie_id
          WHERE cat.code = 'CONTRAVENTION_REVERSEMENT'
            AND o.date_reference = c.date_infraction
            AND o.chauffeur_id IS NOT DISTINCT FROM c.chauffeur_id),
        c.date_paiement,
        c.updated_at::date)
WHERE c.statut = 'REVERSE'
  AND c.date_reversement IS NULL;

CREATE INDEX IF NOT EXISTS idx_contraventions_date_reversement
    ON contraventions (date_reversement);
