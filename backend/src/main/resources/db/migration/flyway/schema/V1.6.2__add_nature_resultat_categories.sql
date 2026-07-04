-- Classification des catégories pour le compte de résultat (cascade V2) :
-- PRODUIT_EXPLOITATION / CHARGE_VARIABLE (varie avec le roulage) /
-- CHARGE_FIXE / HORS_RESULTAT (comptes de tiers : ne doit apparaître ni en
-- produit ni en charge — contraventions refacturées, transferts futurs).
ALTER TABLE categories_operation
    ADD COLUMN IF NOT EXISTS nature_resultat VARCHAR(30);

UPDATE categories_operation SET nature_resultat = 'PRODUIT_EXPLOITATION'
WHERE nature_resultat IS NULL AND type_operation = 'REVENU';

UPDATE categories_operation SET nature_resultat = 'CHARGE_VARIABLE'
WHERE nature_resultat IS NULL
  AND code IN ('VIDANGE', 'REPARATION', 'PNEUMATIQUE', 'FREINAGE', 'PARALISE',
               'TOLERIE', 'PEINTURE', 'EQUIPEMENTS');

UPDATE categories_operation SET nature_resultat = 'CHARGE_FIXE'
WHERE nature_resultat IS NULL AND type_operation = 'DEPENSE';

ALTER TABLE categories_operation
    ALTER COLUMN nature_resultat SET NOT NULL,
    ALTER COLUMN nature_resultat SET DEFAULT 'PRODUIT_EXPLOITATION';

ALTER TABLE categories_operation
    ADD CONSTRAINT chk_categories_operation_nature
    CHECK (nature_resultat IN ('PRODUIT_EXPLOITATION', 'CHARGE_VARIABLE',
                               'CHARGE_FIXE', 'HORS_RESULTAT'));

-- Catégories de tiers pour le circuit des contraventions : le remboursement
-- d'une amende par un chauffeur n'est pas un produit, le reversement à
-- l'État n'est pas une charge (net zéro si refacturé intégralement).
INSERT INTO categories_operation (code, libelle, type_operation, actif, nature_resultat) VALUES
    ('CONTRAVENTION_REMBOURSEMENT', 'Remboursement contravention', 'REVENU',  TRUE, 'HORS_RESULTAT'),
    ('CONTRAVENTION_REVERSEMENT',   'Reversement contravention',   'DEPENSE', TRUE, 'HORS_RESULTAT')
ON CONFLICT (code) DO NOTHING;
