-- =============================================================================
-- V8.0.0__insert_vehicules_jdd.sql
-- Jeux de données véhicules — Environnement TEST
--
-- Utilise des subqueries pour résoudre marque/modèle/type/activité/groupe
-- afin d'éviter tout ID hardcodé.
--
-- Correction : suppression des colonnes libelle et annee (retirées en V1.2.4)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Pré-requis : s'assurer que les marques et modèles manquants existent
-- (absents de V3.0.0 / V4.0.0 mais nécessaires pour ce JDD)
-- -----------------------------------------------------------------------------

-- Marque Dacia (non présente dans V3.0.0)
INSERT INTO marques (nom, type_id, pays_origine, created_at, updated_at)
VALUES ('Dacia', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Roumanie', NOW(), NOW())
ON CONFLICT ON CONSTRAINT uk_marques_nom_type DO NOTHING;

-- Modèles manquants dans V4.0.0
INSERT INTO modeles (nom, type_id, marque_id, created_at, updated_at)
VALUES
    -- Toyota Camry
    ('Camry',
     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
     (SELECT id FROM marques WHERE nom = 'Toyota' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
     NOW(), NOW()),
    -- Dacia Logan
    ('Logan',
     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
     (SELECT id FROM marques WHERE nom = 'Dacia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
     NOW(), NOW()),
    -- Kia Rio
    ('Rio',
     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
     (SELECT id FROM marques WHERE nom = 'Kia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
     NOW(), NOW()),
    -- Hyundai Sonata
    ('Sonata',
     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
     (SELECT id FROM marques WHERE nom = 'Hyundai' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
     NOW(), NOW())
ON CONFLICT ON CONSTRAINT uk_modeles_nom_type_marque DO NOTHING;

-- -----------------------------------------------------------------------------
-- Insertion des véhicules
-- -----------------------------------------------------------------------------

INSERT INTO vehicules (
    immatriculation,
    marque_id,
    modele_id,
    type_vehicule_id,
    type_activite_id,
    groupe_id,
    couleur,
    kilometrage,
    statut,
    date_achat,
    date_prochaine_maintenance,
    created_at,
    updated_at
) VALUES

-- Véhicules premium pour services haut de gamme
('AB-751-PR',
 (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Classe E' AND marque_id = (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test A'),
 'Noir', 8500, 'DISPONIBLE', '2023-01-15', '2024-07-15', NOW(), NOW()),

('BC-752-PR',
 (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Série 5' AND marque_id = (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test A'),
 'Blanc', 9200, 'DISPONIBLE', '2023-02-20', '2024-08-20', NOW(), NOW()),

('CD-753-PR',
 (SELECT id FROM marques WHERE nom = 'Audi' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'A6' AND marque_id = (SELECT id FROM marques WHERE nom = 'Audi' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'TAXI'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Gris', 7800, 'EN_SERVICE', '2023-03-10', '2024-09-10', NOW(), NOW()),

-- Véhicules standard pour services réguliers
('DE-754-ST',
 (SELECT id FROM marques WHERE nom = 'Toyota' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Camry' AND marque_id = (SELECT id FROM marques WHERE nom = 'Toyota' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'TAXI'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Bleu', 18500, 'EN_SERVICE', '2022-04-05', '2024-10-05', NOW(), NOW()),

('EF-755-ST',
 (SELECT id FROM marques WHERE nom = 'Peugeot' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = '508' AND marque_id = (SELECT id FROM marques WHERE nom = 'Peugeot' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test A'),
 'Rouge', 16200, 'EN_SERVICE', '2022-05-12', '2024-11-12', NOW(), NOW()),

('FG-756-ST',
 (SELECT id FROM marques WHERE nom = 'Renault' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Talisman' AND marque_id = (SELECT id FROM marques WHERE nom = 'Renault' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test A'),
 'Noir', 19800, 'EN_SERVICE', '2022-06-18', '2024-12-18', NOW(), NOW()),

-- Véhicules économiques pour services budget
('GH-757-EC',
 (SELECT id FROM marques WHERE nom = 'Dacia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Logan' AND marque_id = (SELECT id FROM marques WHERE nom = 'Dacia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'TAXI'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Gris', 28500, 'DISPONIBLE', '2021-07-22', '2024-06-22', NOW(), NOW()),

('HI-758-EC',
 (SELECT id FROM marques WHERE nom = 'Kia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Rio' AND marque_id = (SELECT id FROM marques WHERE nom = 'Kia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Blanc', 31200, 'DISPONIBLE', '2021-08-30', '2024-07-30', NOW(), NOW()),

-- Véhicules en maintenance
('IJ-759-MT',
 (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Classe A' AND marque_id = (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'TAXI'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Argent', 22000, 'EN_MAINTENANCE', '2022-09-15', '2024-05-15', NOW(), NOW()),

('JK-760-MT',
 (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Série 1' AND marque_id = (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Noir', 26800, 'EN_MAINTENANCE', '2021-10-20', '2024-06-20', NOW(), NOW()),

-- Nouveaux véhicules récemment acquis
('KL-761-NV',
 (SELECT id FROM marques WHERE nom = 'Tesla' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Model 3' AND marque_id = (SELECT id FROM marques WHERE nom = 'Tesla' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test A'),
 'Blanc', 1500, 'DISPONIBLE', '2024-01-05', '2025-01-05', NOW(), NOW()),

('LM-762-NV',
 (SELECT id FROM marques WHERE nom = 'Hyundai' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = 'Sonata' AND marque_id = (SELECT id FROM marques WHERE nom = 'Hyundai' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'TAXI'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test B'),
 'Noir', 1200, 'DISPONIBLE', '2024-02-10', '2025-02-10', NOW(), NOW()),

('MN-763-NV',
 (SELECT id FROM marques WHERE nom = 'Peugeot' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
 (SELECT id FROM modeles WHERE nom = '3008' AND marque_id = (SELECT id FROM marques WHERE nom = 'Peugeot' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
 (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
 (SELECT id FROM types_activite WHERE nom = 'VTC'),
 (SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Test A'),
 'Gris', 800, 'DISPONIBLE', '2024-03-15', '2025-03-15', NOW(), NOW());
