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
    date_mise_en_circulation,
    date_entree_flotte,
    created_at,
    updated_at
) VALUES

-- Véhicules premium pour services haut de gamme
('AA-760-QL-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'Dzire'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Premium'),
'Argent', 8500, 'DISPONIBLE', '2023-01-15', '2024-07-15', '2022-12-01', '2023-01-20', NOW(), NOW()),

('AA-991-SJ-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'Dzire'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Premium'),
'Gris', 9200, 'DISPONIBLE', '2023-02-20', '2024-08-20', '2023-01-10', '2023-02-25', NOW(), NOW()),

('AA-837-TP-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'Dzire'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Blanc', 7800, 'EN_SERVICE', '2023-03-10', '2024-09-10', '2023-02-15', '2023-03-15', NOW(), NOW()),

-- Véhicules standard pour services réguliers
('AA-314-TH-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Premium'),
'Gris', 16200, 'EN_SERVICE', '2022-05-12', '2024-11-12', '2022-04-01', '2022-05-20', NOW(), NOW()),

('AB-929-FE-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Premium'),
'Orange', 19800, 'EN_SERVICE', '2022-06-18', '2024-12-18', '2022-05-10', '2022-06-25', NOW(), NOW()),

('AA-247-YC-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Orange', 18500, 'EN_SERVICE', '2022-04-05', '2024-10-05', '2022-03-01', '2022-04-10', NOW(), NOW()),

-- Véhicules économiques pour services budget
('AB-688-AX',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Orange', 28500, 'DISPONIBLE', '2021-07-22', '2024-06-22', '2021-06-15', '2021-08-01', NOW(), NOW()),

('AA-728-ZT-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Orange', 31200, 'DISPONIBLE', '2021-08-30', '2024-07-30', '2021-07-20', '2021-09-05', NOW(), NOW());

-- Véhicules en maintenance
('AB-192-EJ-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Orange', 22000, 'EN_MAINTENANCE', '2022-09-15', '2024-05-15', '2022-08-10', '2022-09-22', NOW(), NOW()),

('AB-187-EJ-01',
(SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'S-Presso'   AND marque_id = (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Orange', 26800, 'EN_MAINTENANCE', '2021-10-20', '2024-06-20', '2021-09-15', '2021-11-01', NOW(), NOW()),

-- Nouveaux véhicules récemment acquis
('KL-761-NV',
(SELECT id FROM marques WHERE nom = 'Tesla' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'Model 3' AND marque_id = (SELECT id FROM marques WHERE nom = 'Tesla' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Premium'),
'Blanc', 1500, 'DISPONIBLE', '2024-01-05', '2025-01-05', '2023-12-01', '2024-01-10', NOW(), NOW()),

('LM-762-NV',
(SELECT id FROM marques WHERE nom = 'Hyundai' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = 'Sonata' AND marque_id = (SELECT id FROM marques WHERE nom = 'Hyundai' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'TAXI'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Standard'),
'Noir', 1200, 'DISPONIBLE', '2024-02-10', '2025-02-10', '2024-01-15', '2024-02-15', NOW(), NOW()),

('MN-763-NV',
(SELECT id FROM marques WHERE nom = 'Peugeot' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),
(SELECT id FROM modeles WHERE nom = '3008' AND marque_id = (SELECT id FROM marques WHERE nom = 'Peugeot' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture'))),
(SELECT id FROM types_vehicule WHERE nom = 'Voiture'),
(SELECT id FROM types_activite WHERE nom = 'VTC'),
(SELECT id FROM groupes_vehicule WHERE nom = 'Flotte Premium'),
'Gris', 800, 'DISPONIBLE', '2024-03-15', '2025-03-15', '2024-02-20', '2024-03-20', NOW(), NOW());
