-- =============================================================================
-- V10.0.0__insert_permis_conduire_jdd.sql
-- Insertion des permis de conduire comme documents — Environnement TEST
--
-- Correction :
--   - type_documents → types_document (nom de table correct)
--   - chauffeur_id supprimé (V1.1.5) → remplacé par cible = 'CHAUFFEUR' + cible_id
--   - ajout du champ permanence (NOT NULL DEFAULT FALSE)
-- =============================================================================

DO $$
DECLARE
    v_type_id BIGINT;
BEGIN
    SELECT id INTO v_type_id FROM types_document WHERE LOWER(nom) LIKE '%permis%' LIMIT 1;

    IF v_type_id IS NOT NULL THEN

        INSERT INTO documents (
            type_document_id,
            reference,
            date_emission,
            date_expiration,
            statut,
            cible,
            cible_id,
            permanence,
            created_at,
            updated_at
        )
        VALUES
            (v_type_id, 'T-2019-0042', '2019-03-15', '2027-03-15', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'mamadou.diallo@vtcmanager.test'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'T-2020-0117', '2020-07-22', '2028-07-22', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'ibrahim.kone@vtcmanager.test'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'T-2018-0356', '2018-11-30', '2026-11-30', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'julien.martin@vtcmanager.test'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'T-2017-0234', '2017-09-12', '2025-09-12', 'EXPIRE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'thanh.nguyen@vtcmanager.test'),
             FALSE, NOW(), NOW())

        ON CONFLICT DO NOTHING;

        -- Catégories de permis (type B pour tous)
        INSERT INTO document_categories (document_id, categorie)
        SELECT d.id, 'B'
        FROM documents d
        WHERE d.reference IN (
            'T-2019-0042',
            'T-2020-0117',
            'T-2018-0356',
            'T-2017-0234'
        )
        AND d.type_document_id = v_type_id
        ON CONFLICT DO NOTHING;

    END IF;
END $$;
