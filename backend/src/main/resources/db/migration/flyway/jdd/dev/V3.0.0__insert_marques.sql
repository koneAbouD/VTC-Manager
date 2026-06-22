-- Insertion des marques pour l'environnement de développement
INSERT INTO marques (nom, type_id, pays_origine, created_at, updated_at) VALUES
-- Marques de voitures japonaises
('Suzuki', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Japon', NOW(), NOW()),
('Toyota', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Japon', NOW(), NOW()),
('Honda', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Japon', NOW(), NOW()),
('Nissan', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Japon', NOW(), NOW()),
('Mitsubishi', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Japon', NOW(), NOW()),

-- Marques de voitures françaises
('Renault', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'France', NOW(), NOW()),
('Peugeot', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'France', NOW(), NOW()),
('Citroën', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'France', NOW(), NOW()),
('DS', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'France', NOW(), NOW()),

-- Marques de voitures allemandes
('Mercedes-Benz', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Allemagne', NOW(), NOW()),
('BMW', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Allemagne', NOW(), NOW()),
('Audi', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Allemagne', NOW(), NOW()),
('Volkswagen', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Allemagne', NOW(), NOW()),
('Opel', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Allemagne', NOW(), NOW()),

-- Marques de voitures italiennes
('Fiat', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Italie', NOW(), NOW()),
('Alfa Romeo', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Italie', NOW(), NOW()),
('Lancia', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Italie', NOW(), NOW()),

-- Marques de voitures américaines
('Ford', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'États-Unis', NOW(), NOW()),
('Chevrolet', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'États-Unis', NOW(), NOW()),
('Tesla', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'États-Unis', NOW(), NOW()),

-- Marques de voitures coréennes
('Hyundai', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Corée du Sud', NOW(), NOW()),
('Kia', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Corée du Sud', NOW(), NOW()),

-- Marques de voitures suédoises
('Volvo', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Suède', NOW(), NOW()),
('Saab', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Suède', NOW(), NOW()),

-- Marques de voitures tchèques
('Skoda', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'République Tchèque', NOW(), NOW()),

-- Marque Dacia
('Dacia', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), 'Roumanie', NOW(), NOW()),

-- Marques de motos
('Yamaha', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Japon', NOW(), NOW()),
('Honda', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Japon', NOW(), NOW()),
('Kawasaki', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Japon', NOW(), NOW()),
('Suzuki', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Japon', NOW(), NOW()),
('Ducati', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Italie', NOW(), NOW()),
('BMW', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Allemagne', NOW(), NOW()),
('KTM', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'Autriche', NOW(), NOW()),
('Harley-Davidson', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), 'États-Unis', NOW(), NOW()),

-- Marques de camions
('Renault', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'France', NOW(), NOW()),
('Volvo', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Suède', NOW(), NOW()),
('Mercedes-Benz', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Allemagne', NOW(), NOW()),
('Iveco', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Italie', NOW(), NOW()),
('MAN', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Allemagne', NOW(), NOW()),
('Scania', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Suède', NOW(), NOW()),
('DAF', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Pays-Bas', NOW(), NOW()),
('Suzuki', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), 'Japon', NOW(), NOW()),

-- Marques de tricycles
('Piaggio', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), 'Italie', NOW(), NOW()),
('Aixam', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), 'France', NOW(), NOW()),
('Ligier', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), 'France', NOW(), NOW()),
('Microcar', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), 'France', NOW(), NOW());
