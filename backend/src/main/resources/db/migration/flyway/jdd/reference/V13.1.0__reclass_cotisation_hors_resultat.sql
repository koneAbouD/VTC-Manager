-- ─────────────────────────────────────────────────────────────────────────────
-- La cotisation n'est PAS un produit : c'est un dépôt détenu pour le chauffeur,
-- restitué en fin de période (net des créances). On la reclasse donc HORS_RESULTAT
-- (compte de tiers) pour qu'elle sorte du compte de résultat. Le cash reste réel
-- (le chauffeur paie), seul le classement produit disparaît.
--
-- La restitution du net (« prime ») est l'extinction de ce dépôt, HORS_RESULTAT
-- aussi (pas une charge), sinon double comptage produit + charge.
-- Migration corrective : la V12.1.0 étant déjà appliquée, on n'y touche pas.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE categories_operation
    SET nature_resultat = 'HORS_RESULTAT'
    WHERE code = 'ENCAISSEMENT_COTISATIONS';

INSERT INTO categories_operation (code, libelle, type_operation, actif, nature_resultat) VALUES
    ('RESTITUTION_COTISATIONS', 'Restitution cotisations', 'DEPENSE', TRUE, 'HORS_RESULTAT')
ON CONFLICT (code) DO NOTHING;
