-- ─────────────────────────────────────────────────────────────────────────────
-- JDD Éléments maintenance
-- Référence les deux détails créés dans V12.3.0
-- ─────────────────────────────────────────────────────────────────────────────

-- ── DM-001 : Révision 20 000 km Mercedes Classe E  (total 125 500 XOF) ───────
INSERT INTO elements_maintenance (catalogue_element_id, libelle, montant, detail_maintenance_id, created_at, updated_at)
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Filtre à huile'),
    NULL, 12000,
    (SELECT id FROM details_maintenance ORDER BY id ASC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Filtre à air'),
    NULL, 8500,
    (SELECT id FROM details_maintenance ORDER BY id ASC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Huile de vidange'),
    NULL, 25000,
    (SELECT id FROM details_maintenance ORDER BY id ASC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Plaquette de frein'),
    NULL, 45000,
    (SELECT id FROM details_maintenance ORDER BY id ASC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Main d''oeuvre'),
    NULL, 35000,
    (SELECT id FROM details_maintenance ORDER BY id ASC LIMIT 1),
    NOW(), NOW();

-- ── DM-002 : Remplacement 4 pneumatiques BMW Série 5  (total 200 000 XOF) ────
INSERT INTO elements_maintenance (catalogue_element_id, libelle, montant, detail_maintenance_id, created_at, updated_at)
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Pneus'),
    NULL, 160000,
    (SELECT id FROM details_maintenance ORDER BY id DESC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Équilibrage des roues'),
    NULL, 12000,
    (SELECT id FROM details_maintenance ORDER BY id DESC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Parallélisme des roues'),
    NULL, 8000,
    (SELECT id FROM details_maintenance ORDER BY id DESC LIMIT 1),
    NOW(), NOW()
UNION ALL
SELECT
    (SELECT id FROM catalogue_elements_maintenance WHERE libelle = 'Main d''oeuvre'),
    NULL, 20000,
    (SELECT id FROM details_maintenance ORDER BY id DESC LIMIT 1),
    NOW(), NOW();
