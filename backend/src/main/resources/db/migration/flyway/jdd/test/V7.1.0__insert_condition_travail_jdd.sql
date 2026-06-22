-- =============================================================================
-- V7.1.0__insert_condition_travail_jdd.sql
-- Jeux de données conditions de travail — Environnement TEST
--
-- 2 conditions représentatives couvrant les deux grandes variantes :
--   1. Solo Journalier   — 1 chauffeur, montant fixe, espèces
--   2. Alternance Auto   — 2 chauffeurs, rotation automatique, mobile money
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Solo Journalier Espèces
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
    ('RECETTE_NON_VERSEE', 'AMENDE', 60.00, NULL, (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW()),
    ('EXCES_VITESSE',      'BUZZER', NULL,  30,   (SELECT id FROM condition_travail WHERE nom = 'Alternance Automatique 2 Chauffeurs'), NOW(), NOW());
