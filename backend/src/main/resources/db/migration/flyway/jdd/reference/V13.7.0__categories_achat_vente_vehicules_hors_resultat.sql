-- ─────────────────────────────────────────────────────────────────────────────
-- Achat et vente de véhicules : hors résultat.
--
-- Un véhicule est un investissement. Son coût entre dans le résultat par la
-- dotation aux amortissements, calculée sur le prix d'achat de la fiche
-- véhicule ; classer la sortie d'argent de l'achat en charge le compterait une
-- seconde fois. De même, le prix de vente n'est pas un produit : la vente
-- rapporte au plus l'écart entre ce prix et la valeur restant à amortir. Les
-- deux opérations restent dans la trésorerie, elles sortent du compte de
-- résultat.
--
-- Migration corrective : la V12.1.0 étant déjà appliquée, on n'y touche pas.
-- ─────────────────────────────────────────────────────────────────────────────

-- Achat de véhicule. Code identique à celui que l'application dérive du libellé
-- (« Achat de véhicule » → ACHAT_DE_VEHICULE) : une catégorie déjà créée à la
-- main n'est pas dupliquée, elle est seulement remise d'aplomb.
INSERT INTO categories_operation (code, libelle, type_operation, actif, nature_resultat) VALUES
    ('ACHAT_DE_VEHICULE', 'Achat de véhicule', 'DEPENSE', TRUE, 'HORS_RESULTAT')
ON CONFLICT (code) DO UPDATE
    SET nature_resultat = 'HORS_RESULTAT';

-- Son groupe comptable (sous-catégorie, une par catégorie).
INSERT INTO sous_categories_operation (code, libelle, categorie_id, actif)
SELECT 'SC_ACHAT_DE_VEHICULE', 'Investissements', c.id, TRUE
  FROM categories_operation c
 WHERE c.code = 'ACHAT_DE_VEHICULE'
   AND NOT EXISTS (SELECT 1 FROM sous_categories_operation s WHERE s.categorie_id = c.id)
ON CONFLICT (code) DO NOTHING;

-- Ventes de véhicules : était classée produit d'exploitation.
UPDATE categories_operation
   SET nature_resultat = 'HORS_RESULTAT'
 WHERE code = 'VENTES_VEHICULES';
