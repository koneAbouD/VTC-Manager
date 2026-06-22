-- ─────────────────────────────────────────────────────────────────────────────
-- JDD Opérations financières  (~28 opérations sur 3 mois glissants)
-- Catégories et sous-catégories issues de V12.1.0 / V12.2.0
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO operations_financieres
    (reference, type_operation, categorie_id, sous_categorie_id, chauffeur_id, vehicule_id,
     montant, mode_paiement, date_operation, commentaire, statut, detail_maintenance_id)
VALUES

-- ══════════════════════════════════════════════════════════════════════════════
-- MOIS COURANT  (J-1 → J-20)
-- ══════════════════════════════════════════════════════════════════════════════

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0001', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'mamadou.diallo@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'AB-751-PR'),
    85000, 'ESPECES', CURRENT_DATE - 2,
    'Versement hebdomadaire Diallo', 'VALIDEE', NULL
),

-- REVENU — Commissions sur courses (Uber)
(
    'JDD-0002', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'COMMISSIONS_COURSES'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_COMMISSIONS_COURSES'),
    (SELECT id FROM chauffeurs WHERE email = 'ibrahim.kone@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'BC-752-PR'),
    47500, 'MOBILE_MONEY', CURRENT_DATE - 3,
    'Commission Uber — semaine 21', 'VALIDEE', NULL
),

-- DEPENSE — Réparation
(
    'JDD-0003', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'REPARATION'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_REPARATION'),
    NULL,
    (SELECT id FROM vehicules WHERE immatriculation = 'AB-751-PR'),
    28000, 'MOBILE_MONEY', CURRENT_DATE - 5,
    'Remplacement filtre habitacle', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur virement
(
    'JDD-0004', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'ibrahim.kone@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'BC-752-PR'),
    93000, 'MOBILE_MONEY', CURRENT_DATE - 7,
    'Versement virement Koné — semaine 21', 'VALIDEE', NULL
),

-- REVENU — Commissions sur courses (Bolt) — en brouillon
(
    'JDD-0005', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'COMMISSIONS_COURSES'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_COMMISSIONS_COURSES'),
    (SELECT id FROM chauffeurs WHERE email = 'julien.martin@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'CD-753-PR'),
    39500, 'MOBILE_MONEY', CURRENT_DATE - 8,
    'Commission Bolt — mai', 'BROUILLON', NULL
),

-- DEPENSE — Frais bancaire (frais de compte)
(
    'JDD-0006', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'FRAIS_BANCAIRE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_FRAIS_BANCAIRE'),
    NULL, NULL,
    7500, 'MOBILE_MONEY', CURRENT_DATE - 10,
    'Frais de tenue de compte mensuel', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0007', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'julien.martin@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'CD-753-PR'),
    79000, 'ESPECES', CURRENT_DATE - 12,
    'Versement Martin — semaine 20', 'VALIDEE', NULL
),

-- DEPENSE — Réparation véhicule
(
    'JDD-0008', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'REPARATION'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_REPARATION'),
    NULL,
    (SELECT id FROM vehicules WHERE immatriculation = 'BC-752-PR'),
    32000, 'MOBILE_MONEY', CURRENT_DATE - 14,
    'Remplacement courroie accessoires', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0009', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'rachid.benali@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'DE-754-ST'),
    88000, 'ESPECES', CURRENT_DATE - 16,
    'Versement Benali — semaine 20', 'VALIDEE', NULL
),

-- REVENU — Commissions sur courses (Heetch)
(
    'JDD-0010', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'COMMISSIONS_COURSES'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_COMMISSIONS_COURSES'),
    (SELECT id FROM chauffeurs WHERE email = 'rachid.benali@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'DE-754-ST'),
    43000, 'MOBILE_MONEY', CURRENT_DATE - 18,
    'Commission Heetch — avril', 'VALIDEE', NULL
),

-- ══════════════════════════════════════════════════════════════════════════════
-- MOIS PRÉCÉDENT  (J-31 → J-60)
-- ══════════════════════════════════════════════════════════════════════════════

-- DEPENSE — Frais bancaire (assurance flotte)
(
    'JDD-0011', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'FRAIS_BANCAIRE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_FRAIS_BANCAIRE'),
    NULL, NULL,
    120000, 'MOBILE_MONEY', CURRENT_DATE - 32,
    'Prime assurance mensuelle flotte', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur virement
(
    'JDD-0012', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'carlos.garcia@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'EF-755-ST'),
    96000, 'MOBILE_MONEY', CURRENT_DATE - 34,
    'Versement Garcia — semaine 18', 'VALIDEE', NULL
),

-- DEPENSE — Équipements (GPS fleet)
(
    'JDD-0013', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'EQUIPEMENTS'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_EQUIPEMENTS'),
    NULL,
    (SELECT id FROM vehicules WHERE immatriculation = 'KL-761-NV'),
    45000, 'MOBILE_MONEY', CURRENT_DATE - 36,
    'Boîtier télématique GPS flotte', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0014', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'thomas.dupont@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'FG-756-ST'),
    71000, 'ESPECES', CURRENT_DATE - 38,
    'Versement Dupont — semaine 17', 'VALIDEE', NULL
),

-- DEPENSE — Maintenance (révision complète Mercedes, avec détail)
(
    'JDD-0015', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'MAINTENANCE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_MAINTENANCE'),
    NULL,
    (SELECT id FROM vehicules WHERE immatriculation = 'AB-751-PR'),
    125500, 'MOBILE_MONEY', CURRENT_DATE - 40,
    'Révision 20 000 km Mercedes Classe E', 'VALIDEE',
    (SELECT id FROM details_maintenance ORDER BY id ASC LIMIT 1)
),

-- REVENU — Commissions sur courses (Uber)
(
    'JDD-0016', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'COMMISSIONS_COURSES'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_COMMISSIONS_COURSES'),
    (SELECT id FROM chauffeurs WHERE email = 'carlos.garcia@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'EF-755-ST'),
    52000, 'MOBILE_MONEY', CURRENT_DATE - 42,
    'Commission Uber — semaine 17', 'VALIDEE', NULL
),

-- DEPENSE — Frais bancaire (forfait téléphonique)
(
    'JDD-0017', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'FRAIS_BANCAIRE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_FRAIS_BANCAIRE'),
    NULL, NULL,
    18000, 'MOBILE_MONEY', CURRENT_DATE - 44,
    'Forfait professionnel 4 lignes', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0018', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'mamadou.diallo@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'AB-751-PR'),
    82000, 'ESPECES', CURRENT_DATE - 46,
    'Versement Diallo — semaine 16', 'VALIDEE', NULL
),

-- DEPENSE — Marketing et publicité
(
    'JDD-0019', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'MARKETING_PUBLICITE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_MARKETING_PUBLICITE'),
    NULL, NULL,
    25000, 'MOBILE_MONEY', CURRENT_DATE - 48,
    'Campagne publicité réseaux sociaux', 'VALIDEE', NULL
),

-- REVENU — Commissions sur courses — ANNULEE (doublon)
(
    'JDD-0020', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'COMMISSIONS_COURSES'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_COMMISSIONS_COURSES'),
    (SELECT id FROM chauffeurs WHERE email = 'thomas.dupont@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'FG-756-ST'),
    38000, 'MOBILE_MONEY', CURRENT_DATE - 50,
    'Annulé — doublon plateforme', 'ANNULEE', NULL
),

-- ══════════════════════════════════════════════════════════════════════════════
-- IL Y A 2 MOIS  (J-61 → J-90)
-- ══════════════════════════════════════════════════════════════════════════════

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0021', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'ibrahim.kone@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'BC-752-PR'),
    87000, 'ESPECES', CURRENT_DATE - 62,
    'Versement Koné — semaine 12', 'VALIDEE', NULL
),

-- DEPENSE — Frais bancaire (assurance RC)
(
    'JDD-0022', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'FRAIS_BANCAIRE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_FRAIS_BANCAIRE'),
    NULL, NULL,
    95000, 'MOBILE_MONEY', CURRENT_DATE - 64,
    'Prime RC professionnelle T2', 'VALIDEE', NULL
),

-- DEPENSE — Maintenance (remplacement pneumatiques BMW, avec détail)
(
    'JDD-0023', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'MAINTENANCE'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_MAINTENANCE'),
    NULL,
    (SELECT id FROM vehicules WHERE immatriculation = 'BC-752-PR'),
    200000, 'MOBILE_MONEY', CURRENT_DATE - 66,
    'Remplacement 4 pneumatiques BMW Série 5', 'VALIDEE',
    (SELECT id FROM details_maintenance ORDER BY id DESC LIMIT 1)
),

-- REVENU — Encaissement chauffeur espèces
(
    'JDD-0024', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'rachid.benali@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'DE-754-ST'),
    91000, 'ESPECES', CURRENT_DATE - 68,
    'Versement Benali — semaine 11', 'VALIDEE', NULL
),

-- DEPENSE — Intérêts sur les prêts véhicules
(
    'JDD-0025', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'INTERETS_PRETS_VEHICULES'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_INTERETS_PRETS_VEHICULES'),
    NULL,
    (SELECT id FROM vehicules WHERE immatriculation = 'BC-752-PR'),
    29000, 'MOBILE_MONEY', CURRENT_DATE - 70,
    'Mensualité crédit véhicule BMW', 'VALIDEE', NULL
),

-- REVENU — Remboursement (sinistre)
(
    'JDD-0026', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'REMBOURSEMENT'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_REMBOURSEMENT'),
    NULL,
    (SELECT id FROM vehicules  WHERE immatriculation = 'EF-755-ST'),
    45000, 'MOBILE_MONEY', CURRENT_DATE - 72,
    'Remboursement sinistre assurance mars', 'VALIDEE', NULL
),

-- DEPENSE — Frais de formation
(
    'JDD-0027', 'DEPENSE',
    (SELECT id FROM categories_operation     WHERE code = 'FRAIS_FORMATION'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_FRAIS_FORMATION'),
    NULL, NULL,
    12000, 'ESPECES', CURRENT_DATE - 75,
    'Formation conduite préventive chauffeurs', 'VALIDEE', NULL
),

-- REVENU — Encaissement chauffeur espèces — brouillon
(
    'JDD-0028', 'REVENU',
    (SELECT id FROM categories_operation     WHERE code = 'ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM sous_categories_operation WHERE code = 'SC_ENCAISSEMENT_CHAUFFEUR'),
    (SELECT id FROM chauffeurs WHERE email = 'julien.martin@vtcmanager.dev'),
    (SELECT id FROM vehicules  WHERE immatriculation = 'CD-753-PR'),
    75000, 'ESPECES', CURRENT_DATE - 78,
    'Versement Martin — semaine 9', 'BROUILLON', NULL
);
