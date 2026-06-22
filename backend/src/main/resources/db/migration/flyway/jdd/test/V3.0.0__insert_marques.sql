-- Insertion des marques pour l'environnement de développement
INSERT INTO marques (nom, type_id, pays_origine, created_at, updated_at) VALUES
-- Marques de voitures françaises
('Renault', 1, 'France', NOW(), NOW()),
('Peugeot', 1, 'France', NOW(), NOW()),
('Citroën', 1, 'France', NOW(), NOW()),
('DS', 1, 'France', NOW(), NOW()),

-- Marques de voitures allemandes
('Mercedes-Benz', 1, 'Allemagne', NOW(), NOW()),
('BMW', 1, 'Allemagne', NOW(), NOW()),
('Audi', 1, 'Allemagne', NOW(), NOW()),
('Volkswagen', 1, 'Allemagne', NOW(), NOW()),
('Opel', 1, 'Allemagne', NOW(), NOW()),

-- Marques de voitures italiennes
('Fiat', 1, 'Italie', NOW(), NOW()),
('Alfa Romeo', 1, 'Italie', NOW(), NOW()),
('Lancia', 1, 'Italie', NOW(), NOW()),

-- Marques de voitures japonaises
('Toyota', 1, 'Japon', NOW(), NOW()),
('Honda', 1, 'Japon', NOW(), NOW()),
('Nissan', 1, 'Japon', NOW(), NOW()),
('Mitsubishi', 1, 'Japon', NOW(), NOW()),
('Suzuki', 1, 'Japon', NOW(), NOW()),

-- Marques de voitures américaines
('Ford', 1, 'États-Unis', NOW(), NOW()),
('Chevrolet', 1, 'États-Unis', NOW(), NOW()),
('Tesla', 1, 'États-Unis', NOW(), NOW()),

-- Marques de voitures coréennes
('Hyundai', 1, 'Corée du Sud', NOW(), NOW()),
('Kia', 1, 'Corée du Sud', NOW(), NOW()),

-- Marques de voitures suédoises
('Volvo', 1, 'Suède', NOW(), NOW()),
('Saab', 1, 'Suède', NOW(), NOW()),

-- Marques de voitures tchèques
('Skoda', 1, 'République Tchèque', NOW(), NOW()),

-- Marques de motos
('Yamaha', 3, 'Japon', NOW(), NOW()),
('Honda', 3, 'Japon', NOW(), NOW()),
('Kawasaki', 3, 'Japon', NOW(), NOW()),
('Suzuki', 3, 'Japon', NOW(), NOW()),
('Ducati', 3, 'Italie', NOW(), NOW()),
('BMW', 3, 'Allemagne', NOW(), NOW()),
('KTM', 3, 'Autriche', NOW(), NOW()),
('Harley-Davidson', 3, 'États-Unis', NOW(), NOW()),

-- Marques de camions
('Renault Trucks', 2, 'France', NOW(), NOW()),
('Volvo Trucks', 2, 'Suède', NOW(), NOW()),
('Mercedes-Benz Trucks', 2, 'Allemagne', NOW(), NOW()),
('Iveco', 2, 'Italie', NOW(), NOW()),
('MAN', 2, 'Allemagne', NOW(), NOW()),
('Scania', 2, 'Suède', NOW(), NOW()),
('DAF', 2, 'Pays-Bas', NOW(), NOW()),
('Suzuki Trucks', 2, 'Japon', NOW(), NOW()),

-- Marques de tricycles
('Piaggio', 4, 'Italie', NOW(), NOW()),
('Aixam', 4, 'France', NOW(), NOW()),
('Ligier', 4, 'France', NOW(), NOW()),
('Microcar', 4, 'France', NOW(), NOW());
