-- ─────────────────────────────────────────────────────────────────────────────
-- Éléments de maintenance : un prix et une image par modèle de véhicule.
--
-- Un élément du catalogue ne porte plus que ce qui vaut pour tous les modèles
-- (libellé, type de maintenance, activation). Ce qui dépend du modèle part dans
-- tarifs_elements_maintenance : une ligne par élément et par modèle, avec son
-- prix, son image et son activation. Un élément n'est proposé à la saisie d'une
-- maintenance que pour les modèles où il a un tarif.
--
-- Reprise de l'existant, sans rien retirer de ce qui est proposé aujourd'hui :
--   * élément commun          → un tarif par modèle de la flotte ;
--   * élément d'une marque    → un tarif par modèle de la flotte de cette marque ;
--   * élément d'un modèle     → un tarif pour ce modèle.
-- La flotte = les modèles des véhicules qui ne sont pas sortis du parc.
--
-- Prix de départ : le dernier prix unitaire payé pour cet élément sur ce modèle,
-- sinon l'ancien montant par défaut, sinon rien. La main d'œuvre reste sans
-- prix : son montant dépend du travail. Image de départ : celle de l'élément,
-- partagée par ses tarifs (le fichier n'est pas dupliqué).
--
-- Sur une base neuve, ce script passe avant l'insertion du catalogue de
-- référence (V11.0.0), qui ne renseigne que le libellé : aucun tarif n'est créé,
-- il n'y a pas encore de flotte.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS tarifs_elements_maintenance (
    id                   BIGSERIAL      PRIMARY KEY,
    catalogue_element_id BIGINT         NOT NULL
        REFERENCES catalogue_elements_maintenance (id) ON DELETE CASCADE,
    modele_id            BIGINT         NOT NULL REFERENCES modeles (id),
    prix                 NUMERIC(19, 2),
    image                VARCHAR(512),
    actif                BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMP      NOT NULL DEFAULT now(),
    updated_at           TIMESTAMP      NOT NULL DEFAULT now(),
    CONSTRAINT uk_tarifs_elements_maintenance_element_modele
        UNIQUE (catalogue_element_id, modele_id),
    CONSTRAINT ck_tarifs_elements_maintenance_prix CHECK (prix IS NULL OR prix >= 0)
);

CREATE INDEX IF NOT EXISTS idx_tarifs_elements_maintenance_modele
    ON tarifs_elements_maintenance (modele_id);

-- Modèles de la flotte, avec leur marque.
CREATE TEMP TABLE tmp_modeles_flotte ON COMMIT DROP AS
SELECT DISTINCT v.modele_id, mo.marque_id
FROM vehicules v
JOIN modeles mo ON mo.id = v.modele_id
WHERE v.statut IS DISTINCT FROM 'HORS_PARC';

-- 1. Un tarif pour chaque modèle auquel l'élément est proposé aujourd'hui.
INSERT INTO tarifs_elements_maintenance (catalogue_element_id, modele_id)
SELECT ce.id, f.modele_id
FROM catalogue_elements_maintenance ce
JOIN tmp_modeles_flotte f
  ON ce.modele_id IS NULL
 AND (ce.marque_id IS NULL OR ce.marque_id = f.marque_id)
UNION
SELECT ce.id, ce.modele_id
FROM catalogue_elements_maintenance ce
WHERE ce.modele_id IS NOT NULL
ON CONFLICT (catalogue_element_id, modele_id) DO NOTHING;

-- 2. Prix de départ : le dernier prix unitaire payé sur ce modèle. Le véhicule
-- vient de la maintenance, ou à défaut de la dépense saisie directement.
WITH payes AS (
    SELECT e.catalogue_element_id                          AS element_id,
           v.modele_id                                     AS modele_id,
           e.montant / GREATEST(COALESCE(e.quantite, 1), 1) AS prix_unitaire,
           COALESCE(m.date_effectuee, m.date_prevue, o.date_operation) AS jour,
           e.id                                            AS ligne_id
    FROM elements_maintenance e
    LEFT JOIN maintenances m
           ON m.detail_maintenance_id = e.detail_maintenance_id
    LEFT JOIN operations_financieres o
           ON o.detail_maintenance_id = e.detail_maintenance_id
          AND m.id IS NULL
    JOIN vehicules v ON v.id = COALESCE(m.vehicule_id, o.vehicule_id)
    WHERE e.catalogue_element_id IS NOT NULL
      AND e.montant > 0
),
dernier AS (
    SELECT DISTINCT ON (element_id, modele_id) element_id, modele_id, prix_unitaire
    FROM payes
    ORDER BY element_id, modele_id, jour DESC NULLS LAST, ligne_id DESC
)
UPDATE tarifs_elements_maintenance t
SET prix = ROUND(d.prix_unitaire, 0)
FROM dernier d, catalogue_elements_maintenance ce
WHERE d.element_id = t.catalogue_element_id
  AND d.modele_id = t.modele_id
  AND ce.id = t.catalogue_element_id
  AND lower(ce.libelle) NOT LIKE 'main d%uvre%';

-- 3. À défaut de prix payé, l'ancien montant par défaut.
UPDATE tarifs_elements_maintenance t
SET prix = ce.montant_defaut
FROM catalogue_elements_maintenance ce
WHERE ce.id = t.catalogue_element_id
  AND t.prix IS NULL
  AND ce.montant_defaut IS NOT NULL
  AND lower(ce.libelle) NOT LIKE 'main d%uvre%';

-- 4. Image de départ : celle de l'élément.
UPDATE tarifs_elements_maintenance t
SET image = ce.image
FROM catalogue_elements_maintenance ce
WHERE ce.id = t.catalogue_element_id
  AND ce.image IS NOT NULL
  AND ce.image <> '';

-- 5. Contrôle : chaque véhicule de la flotte se voit proposer exactement les
-- mêmes éléments qu'avant. Sinon, la migration s'arrête et rien n'est changé.
DO $$
DECLARE
    ecarts INTEGER;
BEGIN
    WITH avant AS (
        SELECT v.id AS vehicule_id, ce.id AS element_id
        FROM vehicules v
        JOIN modeles mo ON mo.id = v.modele_id
        JOIN catalogue_elements_maintenance ce
          ON ce.marque_id IS NULL
          OR (ce.modele_id IS NULL AND ce.marque_id = mo.marque_id)
          OR ce.modele_id = v.modele_id
        WHERE v.statut IS DISTINCT FROM 'HORS_PARC'
    ),
    apres AS (
        SELECT v.id AS vehicule_id, t.catalogue_element_id AS element_id
        FROM vehicules v
        JOIN tarifs_elements_maintenance t ON t.modele_id = v.modele_id
        WHERE v.statut IS DISTINCT FROM 'HORS_PARC'
    )
    SELECT COUNT(*) INTO ecarts FROM (
        (SELECT * FROM avant EXCEPT SELECT * FROM apres)
        UNION ALL
        (SELECT * FROM apres EXCEPT SELECT * FROM avant)
    ) diff;
    IF ecarts > 0 THEN
        RAISE EXCEPTION 'Reprise des tarifs incohérente : % écart(s) entre les éléments proposés avant et après.', ecarts;
    END IF;
END $$;

-- 6. L'élément ne porte plus ce qui dépend du modèle.
ALTER TABLE catalogue_elements_maintenance
    DROP CONSTRAINT IF EXISTS ck_catalogue_elements_maintenance_modele_marque,
    DROP CONSTRAINT IF EXISTS fk_catalogue_elements_maintenance_marque,
    DROP CONSTRAINT IF EXISTS fk_catalogue_elements_maintenance_modele;

DROP INDEX IF EXISTS uk_catalogue_elements_maintenance_libelle_vehicule;
DROP INDEX IF EXISTS idx_catalogue_elements_maintenance_marque;
DROP INDEX IF EXISTS idx_catalogue_elements_maintenance_modele;

ALTER TABLE catalogue_elements_maintenance
    DROP COLUMN IF EXISTS marque_id,
    DROP COLUMN IF EXISTS modele_id,
    DROP COLUMN IF EXISTS montant_defaut,
    DROP COLUMN IF EXISTS image;

-- Un même élément sert désormais tous les modèles : son libellé redevient
-- unique, sans tenir compte de la casse ni des espaces autour.
CREATE UNIQUE INDEX IF NOT EXISTS uk_catalogue_elements_maintenance_libelle_ci
    ON catalogue_elements_maintenance (lower(trim(libelle)));
