-- Nouvelles catégories de dépense de la famille comptable « Documents » :
-- Vignette et Taxe. Rattachées au groupe « Documents » via leur sous-catégorie,
-- et regroupées sous l'entrée « Document » de la répartition (cf. CODES_DOCUMENT
-- dans GetRapportFinancierUseCase).
INSERT INTO categories_operation (code, libelle, type_operation, actif) VALUES
    ('VIGNETTE', 'Vignette', 'DEPENSE', TRUE),
    ('TAXE',     'Taxe',     'DEPENSE', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO sous_categories_operation (code, libelle, categorie_id, actif) VALUES
    ('SC_VIGNETTE', 'Documents',
        (SELECT id FROM categories_operation WHERE code = 'VIGNETTE'), TRUE),
    ('SC_TAXE',     'Documents',
        (SELECT id FROM categories_operation WHERE code = 'TAXE'),     TRUE)
ON CONFLICT (code) DO NOTHING;
