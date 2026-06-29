-- Données de référence : modèles
-- Note: les sous-requêtes de marques filtrent aussi par type_id pour éviter l'ambiguïté
--       des marques présentes dans plusieurs catégories (ex: BMW Voiture ET BMW Moto)

INSERT INTO modeles (nom, type_id, marque_id, created_at, updated_at) VALUES

-- Renault (voitures)
('Clio',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Mégane',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Talisman',(SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Captur',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Kadjar',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Scenic',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Espace',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Zoe',     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Peugeot (voitures)
('208',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Peugeot'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('308',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Peugeot'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('508',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Peugeot'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('2008', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Peugeot'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('3008', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Peugeot'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('5008', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Peugeot'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Citroën (voitures)
('C3',         (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Citroën'    AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('C4',         (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Citroën'    AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('C5',         (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Citroën'    AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('C3 Aircross',(SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Citroën'    AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('C5 Aircross',(SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Citroën'    AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Mercedes-Benz (voitures)
('Classe A', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Classe C', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Classe E', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('GLA',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('GLC',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('GLE',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- BMW (voitures)
('Série 1', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Série 3', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Série 5', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('X1',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('X3',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('X5',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Audi (voitures)
('A1', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('A3', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('A4', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('A6', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Q2', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Q3', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Q5', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Q7', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Audi'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Volkswagen (voitures)
('Polo',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Volkswagen' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Golf',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Volkswagen' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Passat',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Volkswagen' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Tiguan',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Volkswagen' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Touareg', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Volkswagen' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Toyota (voitures)
('Yaris',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Toyota'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Corolla', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Toyota'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Prius',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Toyota'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('RAV4',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Toyota'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('C-HR',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Toyota'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Camry',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Toyota'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Suzuki (voitures)
('S-Presso',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Dzire',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Swift',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Baleno',     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Vitara',     (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('SX4 S-Cross',(SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Ignis',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Jimny',      (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Celerio',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('S-Cross',    (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Ford (voitures)
('Fiesta', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Ford'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Focus',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Ford'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Mondeo', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Ford'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Kuga',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Ford'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Edge',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Ford'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Tesla (voitures)
('Model 3', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Tesla'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Model S',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Tesla'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Model X',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Tesla'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),
('Model Y',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'), (SELECT id FROM marques WHERE nom = 'Tesla'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Dacia
('Logan',   (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),  (SELECT id FROM marques WHERE nom = 'Dacia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),   NOW(), NOW()),

-- Kia
('Rio', (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),  (SELECT id FROM marques WHERE nom = 'Kia' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')), NOW(), NOW()),

-- Hyundai
('Sonata',  (SELECT id FROM types_vehicule WHERE nom = 'Voiture'),  (SELECT id FROM marques WHERE nom = 'Hyundai' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Voiture')),NOW(), NOW()),

-- Yamaha (motos)
('MT-07',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Yamaha'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('YZF-R6', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Yamaha'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('YZF-R1', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Yamaha'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('TMAX',   (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Yamaha'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- Honda (motos)
('CBR600RR',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Honda'      AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('CBR1000RR', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Honda'      AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Africa Twin',(SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Honda'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('NC750X',    (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Honda'      AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- Kawasaki (motos)
('Ninja 650',   (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Kawasaki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Ninja ZX-10R',(SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Kawasaki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Z900',        (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Kawasaki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Versys 650',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Kawasaki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- Ducati (motos)
('Panigale V4',    (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Ducati' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Multistrada V4', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Ducati' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Monster',        (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Ducati' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Streetfighter V4',(SELECT id FROM types_vehicule WHERE nom = 'Moto'),(SELECT id FROM marques WHERE nom = 'Ducati' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- BMW (motos)
('R1250GS', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('S1000RR', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('RnineT',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('F900R',   (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'BMW' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- KTM (motos)
('1290 Super Duke R',(SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'KTM' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('890 Duke R',       (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'KTM' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('790 Adventure',    (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'KTM' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('450 EXC-F',        (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'KTM' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- Harley-Davidson (motos)
('Iron 883',   (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Harley-Davidson' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Fat Boy',    (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Harley-Davidson' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Street Glide',(SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Harley-Davidson' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Road King',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Harley-Davidson' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- Suzuki (motos)
('GSX-R1000',    (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('GSX-R750',     (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('GSX-R600',     (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Hayabusa',     (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('V-Strom 650',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('V-Strom 1000', (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('SV650',        (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Bandit 1250',  (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Gixxer 250',   (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Intruder 1500',(SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('Boulevard M109R',(SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('DR-Z400',      (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),
('RM-Z450',      (SELECT id FROM types_vehicule WHERE nom = 'Moto'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Moto')), NOW(), NOW()),

-- Renault Trucks (camions)
('T', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('K', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('C', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('D', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Renault'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- Volvo Trucks (camions)
('FH',  (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Volvo'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('FM',  (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Volvo'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('FMX', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Volvo'        AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- Mercedes-Benz Trucks (camions)
('Actros',  (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Atego',   (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Econic',  (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Mercedes-Benz' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- Iveco (camions)
('Stralis',   (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Iveco'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Eurocargo', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Iveco'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Daily',     (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Iveco'       AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- MAN (camions)
('TGX', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'MAN'          AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('TGS', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'MAN'          AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('TGM', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'MAN'          AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- Scania (camions)
('R-series', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Scania'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('S-series', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Scania'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('P-series', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Scania'   AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- DAF (camions)
('XF', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'DAF'           AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('CF', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'DAF'           AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('LF', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'DAF'           AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- Suzuki Trucks (camions)
('Carry',       (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Every',       (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Scrum',       (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),
('Jimny Truck', (SELECT id FROM types_vehicule WHERE nom = 'Camion'), (SELECT id FROM marques WHERE nom = 'Suzuki' AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Camion')), NOW(), NOW()),

-- Piaggio (tricycles)
('Ape',    (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Piaggio'  AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),
('Porter', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Piaggio'  AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),

-- Aixam (tricycles)
('City',  (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Aixam'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),
('Cross', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Aixam'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),

-- Ligier (tricycles)
('JS50', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Ligier'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),
('JS60', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Ligier'     AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),

-- Microcar (tricycles)
('M.Go',        (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Microcar'  AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW()),
('M.Go Family', (SELECT id FROM types_vehicule WHERE nom = 'Tricycle'), (SELECT id FROM marques WHERE nom = 'Microcar'  AND type_id = (SELECT id FROM types_vehicule WHERE nom = 'Tricycle')), NOW(), NOW());
