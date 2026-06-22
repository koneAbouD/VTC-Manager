-- =============================================================================
-- V7.1.0__insert_condition_travail_jdd.sql
-- Jeux de données conditions de travail — Environnement DEV
--
-- 5 conditions couvrant les cas d'usage principaux :
--   1. Solo Journalier Espèces        — 1 chauffeur, montant fixe, versement J
--   2. Alternance Automatique         — 2 chauffeurs, rotation 7j, mobile money
--   3. Alternance Manuelle            — 2 chauffeurs, rotation libre, virement
--   4. Premium VTC Solo               — 1 chauffeur haut de gamme, virement
--   5. Taxi Nuit                      — 1 chauffeur, service nocturne, espèces
--
-- Chaque condition inclut ses cotisations et ses pénalités associées.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Solo Journalier Espèces
--    1 chauffeur · 06h–22h · Objectif 150 € · Fixe 80 €/j · Espèces · Journalier
-- -----------------------------------------------------------------------------
INSERT INTO condition_travail (
    nom, nb_chauffeurs, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire,
    objectif_recette, type_recette, montant_jour_salaire,
    mode_encaissement, frequence_versement, jour_versement, heure_versement,
    created_at, updated_at
) VALUES (
    'Solo Journalier Espèces', 1, 'JOURNALIER',
    '06:00', '22:00',
    NULL, NULL, NULL,
    NULL,
    150.00, 'MONTANT_FIXE', 80.00,
    'ESPECES', 'JOURNALIER', NULL, '22:00',
    NOW(), NOW()
);

INSERT INTO cotisation_template (nom, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('Carburant',          20.00, (SELECT id FROM condition_travail WHERE nom = 'Solo Journalier Espèces'), NOW(), NOW()),
    ('Entretien véhicule', 10.00, (SELECT id FROM condition_travail WHERE nom = 'Solo Journalier Espèces'), NOW(), NOW());

INSERT INTO penalite_template (type_penalite, type_sanction, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('RECETTE_NON_VERSEE', 'AMENDE', 50.00, (SELECT id FROM condition_travail WHERE nom = 'Solo Journalier Espèces'), NOW(), NOW());

-- -----------------------------------------------------------------------------
-- 2. Alternance Automatique 2 Chauffeurs
--    2 chauffeurs · 05h–23h · Rotation auto 7j · Objectif 200 € · Fixe 110 €/j
--    Mobile money · Journalier
-- -----------------------------------------------------------------------------
INSERT INTO condition_travail (
    nom, nb_chauffeurs, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire,
    objectif_recette, type_recette, montant_jour_salaire,
    mode_encaissement, frequence_versement, jour_versement, heure_versement,
    created_at, updated_at
) VALUES (
    'Alternance Automatique 2 Chauffeurs', 2, 'JOURNALIER',
    '05:00', '23:00',
    'AUTOMATIQUE', 7, '2024-01-01',
    NULL,
    200.00, 'MONTANT_FIXE', 110.00,
    'MOBILE_MONEY', 'JOURNALIER', NULL, '23:00',
    NOW(), NOW()
);

INSERT INTO cotisation_template (nom, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('Carburant',          25.00, (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW()),
    ('Entretien véhicule', 12.00, (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW()),
    ('Assurance',           8.00, (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW());

INSERT INTO penalite_template (type_penalite, type_sanction, montant, duree_sanction_secondes, condition_travail_id, created_at, updated_at)
VALUES
    ('RECETTE_NON_VERSEE', 'AMENDE',  60.00, NULL, (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW()),
    ('EXCES_VITESSE',      'BUZZER',  NULL,  30,   (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW());

-- -----------------------------------------------------------------------------
-- 3. Alternance Manuelle 2 Chauffeurs
--    2 chauffeurs · 06h–22h · Rotation manuelle · Objectif 160 € · Montant réel
--    Virement · Hebdomadaire le vendredi
-- -----------------------------------------------------------------------------
INSERT INTO condition_travail (
    nom, nb_chauffeurs, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire,
    objectif_recette, type_recette, montant_jour_salaire,
    mode_encaissement, frequence_versement, jour_versement, heure_versement,
    created_at, updated_at
) VALUES (
    'Alternance Manuelle 2 Chauffeurs', 2, 'JOURNALIER',
    '06:00', '22:00',
    'MANUELLE', NULL, NULL,
    NULL,
    160.00, 'MONTANT_REEL', NULL,
    'LES_DEUX', 'HEBDOMADAIRE', 'VENDREDI', '18:00',
    NOW(), NOW()
);

INSERT INTO cotisation_template (nom, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('Carburant',          20.00, (SELECT id FROM condition_travail WHERE nom = 'Alternance Manuelle 2 Chauffeurs'), NOW(), NOW()),
    ('Entretien véhicule', 10.00, (SELECT id FROM condition_travail WHERE nom = 'Alternance Manuelle 2 Chauffeurs'), NOW(), NOW());

INSERT INTO penalite_template (type_penalite, type_sanction, duree_sanction_secondes, condition_travail_id, created_at, updated_at)
VALUES
    ('HEURE_FIN_SERVICE_PASSE', 'BUZZER', 60, (SELECT id FROM condition_travail WHERE nom = 'Alternance Manuelle 2 Chauffeurs'), NOW(), NOW());

-- -----------------------------------------------------------------------------
-- 4. Premium VTC Solo
--    1 chauffeur · 08h–20h · Objectif 250 € · Fixe 150 €/j · Virement · Journalier
--    Jour de salaire : vendredi
-- -----------------------------------------------------------------------------
INSERT INTO condition_travail (
    nom, nb_chauffeurs, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire,
    objectif_recette, type_recette, montant_jour_salaire,
    mode_encaissement, frequence_versement, jour_versement, heure_versement,
    created_at, updated_at
) VALUES (
    'Premium VTC Solo', 1, 'JOURNALIER',
    '08:00', '20:00',
    NULL, NULL, NULL,
    'VENDREDI',
    250.00, 'MONTANT_FIXE', 150.00,
    'LES_DEUX', 'JOURNALIER', NULL, '20:00',
    NOW(), NOW()
);

INSERT INTO cotisation_template (nom, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('Carburant',          30.00, (SELECT id FROM condition_travail WHERE nom = 'Premium VTC Solo'), NOW(), NOW()),
    ('Entretien véhicule', 15.00, (SELECT id FROM condition_travail WHERE nom = 'Premium VTC Solo'), NOW(), NOW()),
    ('Réparations',        10.00, (SELECT id FROM condition_travail WHERE nom = 'Premium VTC Solo'), NOW(), NOW());

INSERT INTO penalite_template (type_penalite, type_sanction, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('RECETTE_NON_VERSEE', 'AMENDE', 75.00, (SELECT id FROM condition_travail WHERE nom = 'Premium VTC Solo'), NOW(), NOW()),
    ('EXCES_VITESSE',      'AMENDE', 30.00, (SELECT id FROM condition_travail WHERE nom = 'Premium VTC Solo'), NOW(), NOW());

-- -----------------------------------------------------------------------------
-- 5. Taxi Nuit
--    1 chauffeur · 20h–08h · Objectif 120 € · Montant réel · Espèces · Journalier
-- -----------------------------------------------------------------------------
INSERT INTO condition_travail (
    nom, nb_chauffeurs, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire,
    objectif_recette, type_recette, montant_jour_salaire,
    mode_encaissement, frequence_versement, jour_versement, heure_versement,
    created_at, updated_at
) VALUES (
    'Taxi Nuit', 1, 'JOURNALIER',
    '20:00', '08:00',
    NULL, NULL, NULL,
    NULL,
    120.00, 'MONTANT_REEL', NULL,
    'ESPECES', 'JOURNALIER', NULL, '08:00',
    NOW(), NOW()
);

INSERT INTO cotisation_template (nom, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('Carburant',          18.00, (SELECT id FROM condition_travail WHERE nom = 'Taxi Nuit'), NOW(), NOW()),
    ('Entretien véhicule',  8.00, (SELECT id FROM condition_travail WHERE nom = 'Taxi Nuit'), NOW(), NOW());

INSERT INTO penalite_template (type_penalite, type_sanction, duree_immobilisation_minutes, condition_travail_id, created_at, updated_at)
VALUES
    ('EXCES_VITESSE', 'IMMOBILISATION', 60, (SELECT id FROM condition_travail WHERE nom = 'Taxi Nuit'), NOW(), NOW());

INSERT INTO penalite_template (type_penalite, type_sanction, montant, condition_travail_id, created_at, updated_at)
VALUES
    ('RECETTE_NON_VERSEE', 'AMENDE', 40.00, (SELECT id FROM condition_travail WHERE nom = 'Taxi Nuit'), NOW(), NOW());
