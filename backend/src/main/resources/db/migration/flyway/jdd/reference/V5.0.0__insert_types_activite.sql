-- Données de référence : types d'activité
INSERT INTO types_activite (nom, description, created_at, updated_at) VALUES
('VTC', 'Véhicule de Transport avec Chauffeur', NOW(), NOW()),
('TAXI', 'Transport public de personnes avec taximètre', NOW(), NOW()),
('LIVRAISON', 'Transport et livraison de marchandises', NOW(), NOW()),
('LOCATION', 'Location de véhicule avec ou sans chauffeur', NOW(), NOW());
