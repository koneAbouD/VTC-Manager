-- Insertion des groupes de véhicules pour l'environnement de test

INSERT INTO groupes_vehicule (nom, description, statut, created_at, updated_at) VALUES
('Flotte Test A', 'Groupe de test principal', 'ACTIF', NOW(), NOW()),
('Flotte Test B', 'Groupe de test secondaire', 'INACTIF', NOW(), NOW());