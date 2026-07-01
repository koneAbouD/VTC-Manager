-- ─────────────────────────────────────────────────────────────────────────────
-- JDD Catégories d'opération
-- Revenus : 12 catégories  |  Dépenses : 11 catégories
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO categories_operation (code, libelle, type_operation, actif) VALUES

    -- ── REVENUS ──────────────────────────────────────────────────────────────
    ('ENCAISSEMENT_RECETTES',       'Recettes',                     'REVENU',  TRUE),
    ('ENCAISSEMENT_COTISATIONS',    'Cotisations',                  'REVENU',  TRUE),
    ('ENCAISSEMENT_PENALITES',      'Pénalités',                    'REVENU',  TRUE),
    ('REVENTE_PIECES_SERVICES',     'Revente pièces ou services annexes',        'REVENU',  TRUE),
    ('COMMISSIONS_COURSES',         'Commissions sur courses',                   'REVENU',  TRUE),
    ('FRAIS_ABO_CHAUFFEURS',        'Frais abonnement (chauffeurs/partenaires)', 'REVENU',  TRUE),
    ('SOUTIENS_FINANCIERS',         'Soutiens financiers',                       'REVENU',  TRUE),
    ('VENTES_VEHICULES',            'Ventes de véhicules',                       'REVENU',  TRUE),
    ('DIVERS_REVENU',               'Divers',                                    'REVENU',  TRUE),
    ('REMBOURSEMENT',               'Remboursement',                             'REVENU',  TRUE),
    ('REGLEMENT_AVANCE',            'Règlement avance',                          'REVENU',  TRUE),
    ('INDEMNISATIONS',              'Indemnisations',                            'REVENU',  TRUE),

    -- ── DÉPENSES ─────────────────────────────────────────────────────────────
    ('VIDANGE',                     'Vidange',                                   'DEPENSE', TRUE),
    ('REPARATION',                  'Réparation',                                'DEPENSE', TRUE),
    ('PNEUMATIQUE',                 'Pneumatiques',                              'DEPENSE', TRUE),
    ('FREINAGE',                    'Freinage',                                  'DEPENSE', TRUE),
    ('PARALISE',                    'Paralysie',                                 'DEPENSE', TRUE),
    ('TOLERIE',                     'Tôlerie',                                   'DEPENSE', TRUE),
    ('PEINTURE',                    'Peinture',                                  'DEPENSE', TRUE),
    ('ASSURANCE',                   'Assurance',                                 'DEPENSE', TRUE),
    ('VISITE_TECHNIQUE',            'Visite technique',                          'DEPENSE', TRUE),
    ('PATENTE',                     'Patente',                                   'DEPENSE', TRUE),
    ('CARTE_STATIONNEMENT',         'Carte de stationnement',                    'DEPENSE', TRUE),
    ('FRAIS_BANCAIRE',              'Frais bancaire',                            'DEPENSE', TRUE),
    ('MARKETING_PUBLICITE',         'Marketing et publicité',                    'DEPENSE', TRUE),
    ('FRAIS_FORMATION',             'Frais de formation',                        'DEPENSE', TRUE),
    ('EQUIPEMENTS',                 'Équipements',                               'DEPENSE', TRUE),
    ('INTERETS_PRETS_VEHICULES',    'Intérêts sur les prêts véhicules',          'DEPENSE', TRUE)

ON CONFLICT (code) DO NOTHING;
