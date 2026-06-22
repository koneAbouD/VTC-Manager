-- Référentiel des éléments de maintenance - inspiré de l'interface mobile

INSERT INTO catalogue_elements_maintenance (libelle, actif, created_at, updated_at) VALUES
    -- Filtration
    ('Filtre à air',                TRUE, NOW(), NOW()),
    ('Filtre à carburant',          TRUE, NOW(), NOW()),
    ('Filtre à huile',              TRUE, NOW(), NOW()),
    ('Filtre à pollen',             TRUE, NOW(), NOW()),

    -- Fluides
    ('Huile de vidange',            TRUE, NOW(), NOW()),
    ('Liquide de frein',            TRUE, NOW(), NOW()),
    ('Liquide de refroidissement',  TRUE, NOW(), NOW()),
    ('Liquide de direction',        TRUE, NOW(), NOW()),

    -- Freinage
    ('Plaquette de frein',          TRUE, NOW(), NOW()),
    ('Disque de frein',             TRUE, NOW(), NOW()),
    ('Tambour de frein',            TRUE, NOW(), NOW()),
    ('Frein à main',                TRUE, NOW(), NOW()),

    -- Pneumatiques & roues
    ('Pneus',                       TRUE, NOW(), NOW()),
    ('Jantes',                      TRUE, NOW(), NOW()),
    ('Parallélisme des roues',      TRUE, NOW(), NOW()),
    ('Équilibrage des roues',       TRUE, NOW(), NOW()),

    -- Électricité
    ('Batterie',                    TRUE, NOW(), NOW()),
    ('Phares',                      TRUE, NOW(), NOW()),
    ('Alternateur',                 TRUE, NOW(), NOW()),
    ('Démarreur',                   TRUE, NOW(), NOW()),
    ('Bougies d''allumage',         TRUE, NOW(), NOW()),

    -- Moteur & transmission
    ('Moteur',                      TRUE, NOW(), NOW()),
    ('Courroies',                   TRUE, NOW(), NOW()),
    ('Courroie de distribution',    TRUE, NOW(), NOW()),
    ('Transmission',                TRUE, NOW(), NOW()),
    ('Embrayage',                   TRUE, NOW(), NOW()),
    ('Boîte de vitesses',           TRUE, NOW(), NOW()),

    -- Suspension & direction
    ('Amortisseurs',                TRUE, NOW(), NOW()),
    ('Ressorts',                    TRUE, NOW(), NOW()),
    ('Rotules de direction',        TRUE, NOW(), NOW()),
    ('Biellettes de barre stabilisatrice', TRUE, NOW(), NOW()),

    -- Climatisation & confort
    ('Climatisation',               TRUE, NOW(), NOW()),
    ('Essuie-glaces',               TRUE, NOW(), NOW()),
    ('Rétroviseurs',                TRUE, NOW(), NOW()),

    -- Carrosserie & vitres
    ('Vitres',                      TRUE, NOW(), NOW()),
    ('Carrosserie',                 TRUE, NOW(), NOW()),

    -- Contrôle & diagnostics
    ('Contrôle technique',          TRUE, NOW(), NOW()),
    ('Diagnostic électronique',     TRUE, NOW(), NOW()),

    -- Main d''oeuvre
    ('Main d''oeuvre',              TRUE, NOW(), NOW())

ON CONFLICT (libelle) DO NOTHING;
