-- Le fournisseur devient « partenaire ».
--
-- L'entreprise ne traite pas qu'avec des fournisseurs : elle paie aussi un
-- bailleur, un assureur, l'administration, des prestataires de service. Le
-- tiers est donc renommé partenaire, et sa nature — jusqu'ici figée dans un
-- enum de code — descend dans les données de référence : on ajoute une famille
-- de partenaires sans redéploiement.
--
-- Dans la foulée, le partenaire devient saisissable là où il manquait : sur les
-- maintenances (le prestataire n'était qu'un texte libre, impossible à
-- regrouper) et sur les opérations financières.

-- ── 1. Référentiel des types de partenaire ──────────────────────────────────

CREATE TABLE IF NOT EXISTS types_partenaire (
    id          BIGSERIAL    PRIMARY KEY,
    nom         VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    actif       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_types_partenaire_nom UNIQUE (nom)
);

-- Les natures de départ. Elles sont semées ici, et non dans les jeux de données
-- de référence, parce que la reprise ci-dessous en dépend : sans elles, aucun
-- partenaire existant ne pourrait être rattaché à sa famille.
INSERT INTO types_partenaire (nom, description) VALUES
    ('Prestataire',    'Garage, mécanicien, lavage — une prestation de service.'),
    ('Fournisseur',    'Vente de biens : pièces détachées, carburant, consommables.'),
    ('Administration', 'État et régies : vignette, patente, taxes.'),
    ('Bailleur',       'Propriétaire d''un local ou d''un véhicule loué.'),
    ('Assurance',      'Assureur ou courtier.'),
    ('Autre',          'Tiers ne relevant d''aucune des familles ci-dessus.')
ON CONFLICT (nom) DO NOTHING;

-- ── 2. fournisseurs → partenaires ───────────────────────────────────────────

ALTER TABLE IF EXISTS fournisseurs RENAME TO partenaires;
ALTER SEQUENCE IF EXISTS fournisseurs_id_seq RENAME TO partenaires_id_seq;

-- Les noms de contraintes ne sont renommés que s'ils existent : la base de dev
-- a été construite en partie par Hibernate, qui les nomme autrement.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_fournisseurs_nom') THEN
        ALTER TABLE partenaires RENAME CONSTRAINT uk_fournisseurs_nom TO uk_partenaires_nom;
    END IF;
END $$;

ALTER TABLE partenaires DROP CONSTRAINT IF EXISTS chk_fournisseurs_type;
ALTER INDEX IF EXISTS idx_fournisseurs_actif RENAME TO idx_partenaires_actif;

-- Le type quitte l'enum pour le référentiel.
ALTER TABLE partenaires ADD COLUMN IF NOT EXISTS type_partenaire_id BIGINT;

-- Reprise : chaque ancienne valeur d'enum retrouve sa famille. GARAGE devient
-- un prestataire (service rendu), PIECES et CARBURANT des fournisseurs de
-- biens — la distinction pièces/carburant se lit désormais sur la catégorie de
-- la charge, pas sur le tiers.
UPDATE partenaires p
   SET type_partenaire_id = t.id
  FROM types_partenaire t
 WHERE p.type_partenaire_id IS NULL
   AND t.nom = CASE p.type
                   WHEN 'GARAGE'         THEN 'Prestataire'
                   WHEN 'PIECES'         THEN 'Fournisseur'
                   WHEN 'CARBURANT'      THEN 'Fournisseur'
                   WHEN 'ASSURANCE'      THEN 'Assurance'
                   WHEN 'ADMINISTRATION' THEN 'Administration'
                   WHEN 'BAILLEUR'       THEN 'Bailleur'
                   ELSE 'Autre'
               END;

UPDATE partenaires
   SET type_partenaire_id = (SELECT id FROM types_partenaire WHERE nom = 'Autre')
 WHERE type_partenaire_id IS NULL;

ALTER TABLE partenaires ALTER COLUMN type_partenaire_id SET NOT NULL;
ALTER TABLE partenaires DROP CONSTRAINT IF EXISTS fk_partenaires_type;
ALTER TABLE partenaires
    ADD CONSTRAINT fk_partenaires_type FOREIGN KEY (type_partenaire_id)
        REFERENCES types_partenaire(id);
CREATE INDEX IF NOT EXISTS idx_partenaires_type ON partenaires(type_partenaire_id);

ALTER TABLE partenaires DROP COLUMN IF EXISTS type;

-- ── 3. factures_fournisseur → factures_partenaire ───────────────────────────

ALTER TABLE IF EXISTS factures_fournisseur RENAME TO factures_partenaire;
ALTER SEQUENCE IF EXISTS factures_fournisseur_id_seq RENAME TO factures_partenaire_id_seq;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_name = 'factures_partenaire' AND column_name = 'fournisseur_id') THEN
        ALTER TABLE factures_partenaire RENAME COLUMN fournisseur_id TO partenaire_id;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_factures_fournisseur_reference') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT uk_factures_fournisseur_reference TO uk_factures_partenaire_reference;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_factures_fournisseur_tiers') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT fk_factures_fournisseur_tiers TO fk_factures_partenaire_tiers;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_factures_fournisseur_categorie') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT fk_factures_fournisseur_categorie TO fk_factures_partenaire_categorie;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_factures_fournisseur_vehicule') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT fk_factures_fournisseur_vehicule TO fk_factures_partenaire_vehicule;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_factures_fournisseur_montant') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT chk_factures_fournisseur_montant TO chk_factures_partenaire_montant;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_factures_fournisseur_paye') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT chk_factures_fournisseur_paye TO chk_factures_partenaire_paye;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_factures_fournisseur_statut') THEN
        ALTER TABLE factures_partenaire
            RENAME CONSTRAINT chk_factures_fournisseur_statut TO chk_factures_partenaire_statut;
    END IF;
END $$;

ALTER INDEX IF EXISTS idx_factures_fournisseur_tiers    RENAME TO idx_factures_partenaire_tiers;
ALTER INDEX IF EXISTS idx_factures_fournisseur_date     RENAME TO idx_factures_partenaire_date;
ALTER INDEX IF EXISTS idx_factures_fournisseur_echeance RENAME TO idx_factures_partenaire_echeance;
ALTER INDEX IF EXISTS idx_factures_fournisseur_ouvertes RENAME TO idx_factures_partenaire_ouvertes;

-- ── 4. Opérations financières : lien facture, et partenaire de l'écriture ────

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_name = 'operations_financieres'
                  AND column_name = 'facture_fournisseur_id') THEN
        ALTER TABLE operations_financieres
            RENAME COLUMN facture_fournisseur_id TO facture_partenaire_id;
    END IF;
END $$;

ALTER INDEX IF EXISTS idx_operations_financieres_facture
    RENAME TO idx_operations_financieres_facture_partenaire;

-- Tiers de l'écriture, indépendamment de toute facture : une dépense payée
-- comptant a bien un partenaire, même sans dette préalable.
ALTER TABLE operations_financieres ADD COLUMN IF NOT EXISTS partenaire_id BIGINT;
ALTER TABLE operations_financieres DROP CONSTRAINT IF EXISTS fk_operations_financieres_partenaire;
ALTER TABLE operations_financieres
    ADD CONSTRAINT fk_operations_financieres_partenaire
        FOREIGN KEY (partenaire_id) REFERENCES partenaires(id);
CREATE INDEX IF NOT EXISTS idx_operations_financieres_partenaire
    ON operations_financieres(partenaire_id)
    WHERE partenaire_id IS NOT NULL;

-- ── 5. Maintenances : le prestataire texte devient un partenaire ────────────

ALTER TABLE maintenances ADD COLUMN IF NOT EXISTS partenaire_id BIGINT;

-- Reprise du texte libre : chaque nom distinct (à la casse près) devient un
-- partenaire de type Prestataire, s'il n'existe pas déjà. Entre deux graphies
-- du même nom, on garde celle qui porte des majuscules — c'est un nom propre
-- qui sera affiché tel quel.
INSERT INTO partenaires (nom, type_partenaire_id, actif, created_at, updated_at)
SELECT src.nom,
       (SELECT id FROM types_partenaire WHERE nom = 'Prestataire'),
       TRUE, NOW(), NOW()
  FROM (SELECT COALESCE(
                   MIN(LEFT(BTRIM(prestataire), 150))
                       FILTER (WHERE BTRIM(prestataire) <> LOWER(BTRIM(prestataire))),
                   MIN(LEFT(BTRIM(prestataire), 150))) AS nom
          FROM maintenances
         WHERE prestataire IS NOT NULL AND BTRIM(prestataire) <> ''
         GROUP BY LOWER(LEFT(BTRIM(prestataire), 150))) src
 WHERE NOT EXISTS (SELECT 1 FROM partenaires p WHERE LOWER(p.nom) = LOWER(src.nom));

UPDATE maintenances m
   SET partenaire_id = p.id
  FROM partenaires p
 WHERE m.partenaire_id IS NULL
   AND m.prestataire IS NOT NULL
   AND LOWER(p.nom) = LOWER(LEFT(BTRIM(m.prestataire), 150));

ALTER TABLE maintenances DROP CONSTRAINT IF EXISTS fk_maintenances_partenaire;
ALTER TABLE maintenances
    ADD CONSTRAINT fk_maintenances_partenaire
        FOREIGN KEY (partenaire_id) REFERENCES partenaires(id);
CREATE INDEX IF NOT EXISTS idx_maintenances_partenaire ON maintenances(partenaire_id);

-- Le texte libre a fini son office : une seule source de vérité désormais.
ALTER TABLE maintenances DROP COLUMN IF EXISTS prestataire;
