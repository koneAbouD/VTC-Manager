-- ─────────────────────────────────────────────────────────────────────────────
-- JDD Sous-catégories d'opération  (relation One-to-One avec categories_operation)
-- Le libellé de la sous-catégorie représente le groupe / la famille comptable.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO sous_categories_operation (code, libelle, categorie_id, actif) VALUES

    -- ── REVENUS ──────────────────────────────────────────────────────────────

    -- Groupe : Revenus exceptionnels
    ('SC_INDEMNISATIONS',
        'Revenus exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'INDEMNISATIONS'),
        TRUE),

    ('SC_ENCAISSEMENT_PENALITES',
        'Encaissement',
        (SELECT id FROM categories_operation WHERE code = 'ENCAISSEMENT_PENALITES'),
        TRUE),

    ('SC_ENCAISSEMENT_RECETTES',
        'Encaissement',
        (SELECT id FROM categories_operation WHERE code = 'ENCAISSEMENT_RECETTES'),
        TRUE),

    ('SC_ENCAISSEMENT_COTISATIONS',
        'Encaissement',
        (SELECT id FROM categories_operation WHERE code = 'ENCAISSEMENT_COTISATIONS'),
        TRUE),

    ('SC_REVENTE_PIECES_SERVICES',
        'Revenus exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'REVENTE_PIECES_SERVICES'),
        TRUE),

    ('SC_VENTES_VEHICULES',
        'Revenus exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'VENTES_VEHICULES'),
        TRUE),

    ('SC_DIVERS_REVENU',
        'Revenus exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'DIVERS_REVENU'),
        TRUE),

    ('SC_REMBOURSEMENT',
        'Revenus exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'REMBOURSEMENT'),
        TRUE),

    ('SC_REGLEMENT_AVANCE',
        'Revenus exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'REGLEMENT_AVANCE'),
        TRUE),

    -- Groupe : Commissions
    ('SC_COMMISSIONS_COURSES',
        'Commissions',
        (SELECT id FROM categories_operation WHERE code = 'COMMISSIONS_COURSES'),
        TRUE),

    ('SC_FRAIS_ABO_CHAUFFEURS',
        'Commissions',
        (SELECT id FROM categories_operation WHERE code = 'FRAIS_ABO_CHAUFFEURS'),
        TRUE),

    -- Groupe : Subventions
    ('SC_SOUTIENS_FINANCIERS',
        'Subventions',
        (SELECT id FROM categories_operation WHERE code = 'SOUTIENS_FINANCIERS'),
        TRUE),

    -- ── DÉPENSES ─────────────────────────────────────────────────────────────

    -- Groupe : Maintenance
    ('SC_REPARATION',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'REPARATION'),
        TRUE),

    ('SC_VIDANGE',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'VIDANGE'),
        TRUE),

    ('SC_PNEUMATIQUE',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'PNEUMATIQUE'),
        TRUE),

    ('SC_FREINAGE',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'FREINAGE'),
        TRUE),

    ('SC_PARALISE',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'PARALISE'),
        TRUE),

    ('SC_TOLERIE',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'TOLERIE'),
        TRUE),

    ('SC_PEINTURE',
        'Maintenances',
        (SELECT id FROM categories_operation WHERE code = 'PEINTURE'),
        TRUE),

    -- Groupe : Documents
        ('SC_ASSURANCE',
            'Documents',
            (SELECT id FROM categories_operation WHERE code = 'ASSURANCE'),
            TRUE),

        ('SC_VISITE_TECHNIQUE',
            'Documents',
            (SELECT id FROM categories_operation WHERE code = 'VISITE_TECHNIQUE'),
            TRUE),

        ('SC_PATENTE',
            'Documents',
            (SELECT id FROM categories_operation WHERE code = 'PATENTE'),
            TRUE),

        ('SC_CARTE_STATIONNEMENT',
             'Documents',
             (SELECT id FROM categories_operation WHERE code = 'CARTE_STATIONNEMENT'),
             TRUE),

    -- Groupe : Frais opérationnels
    ('SC_FRAIS_BANCAIRE',
        'Frais opérationnels',
        (SELECT id FROM categories_operation WHERE code = 'FRAIS_BANCAIRE'),
        TRUE),

    -- Groupe : Publicité ou partenariats
    ('SC_MARKETING_PUBLICITE',
        'Publicité ou partenariats',
        (SELECT id FROM categories_operation WHERE code = 'MARKETING_PUBLICITE'),
        TRUE),

    -- Groupe : Frais exceptionnels
    ('SC_FRAIS_FORMATION',
        'Frais exceptionnels',
        (SELECT id FROM categories_operation WHERE code = 'FRAIS_FORMATION'),
        TRUE),

    -- Groupe : Amortissements et dépréciations
    ('SC_EQUIPEMENTS',
        'Amortissements et dépréciations',
        (SELECT id FROM categories_operation WHERE code = 'EQUIPEMENTS'),
        TRUE),

    -- Groupe : Charges financières
    ('SC_INTERETS_PRETS_VEHICULES',
        'Charges financières',
        (SELECT id FROM categories_operation WHERE code = 'INTERETS_PRETS_VEHICULES'),
        TRUE)

ON CONFLICT (code) DO NOTHING;
