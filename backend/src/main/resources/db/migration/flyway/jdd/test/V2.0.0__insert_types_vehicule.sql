-- Insertion des types de véhicules pour l'environnement de développement
INSERT INTO types_vehicule (nom, description, created_at, updated_at) VALUES
('Voiture', 'Véhicule automobile à quatre roues pour le transport de personnes', NOW(), NOW()),
('Camion', 'Véhicule utilitaire pour le transport de marchandises', NOW(), NOW()),
('Moto', 'Véhicule à deux roues motorisé', NOW(), NOW()),
('Tricycle', 'Véhicule à trois roues motorisé', NOW(), NOW());
