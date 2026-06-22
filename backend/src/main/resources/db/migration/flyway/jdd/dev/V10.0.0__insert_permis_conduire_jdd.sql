-- =============================================================================
-- V10.0.0__insert_permis_conduire_jdd.sql
-- Insertion des permis de conduire comme documents — Environnement DEV
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
            (v_type_id, 'B-2019-0042', '2019-03-15', '2027-03-15', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'mamadou.diallo@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2020-0117', '2020-07-22', '2028-07-22', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'ibrahim.kone@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2018-0356', '2018-11-30', '2026-11-30', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'julien.martin@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2021-0089', '2021-05-18', '2029-05-18', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'rachid.benali@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2017-0234', '2017-09-12', '2025-09-12', 'EXPIRE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'thanh.nguyen@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2022-0501', '2022-02-28', '2030-02-28', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'thomas.dupont@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2020-0678', '2020-12-10', '2028-12-10', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'seydou.traore@vtcmanager.dev'),
             FALSE, NOW(), NOW()),

            (v_type_id, 'B-2019-0812', '2019-08-05', '2027-08-05', 'VALIDE',
             'CHAUFFEUR', (SELECT id FROM chauffeurs WHERE email = 'carlos.garcia@vtcmanager.dev'),
             FALSE, NOW(), NOW())

        ON CONFLICT DO NOTHING;

        -- Catégories de permis (type B pour tous)
        INSERT INTO document_categories (document_id, categorie)
        SELECT d.id, 'B'
        FROM documents d
        WHERE d.reference IN (
            'B-2019-0042',
            'B-2020-0117',
            'B-2018-0356',
            'B-2021-0089',
            'B-2017-0234',
            'B-2022-0501',
            'B-2020-0678',
            'B-2019-0812'
        )
        AND d.type_document_id = v_type_id
        ON CONFLICT DO NOTHING;

    END IF;
END $$;
