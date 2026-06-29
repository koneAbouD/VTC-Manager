-- Données de référence : types de documents

INSERT INTO types_document (nom, cible, obligatoire) VALUES
-- Documents pour les véhicules
('Carte grise', 'VEHICULE', true),
('Assurance véhicule', 'VEHICULE', true),
('Vignette', 'VEHICULE', true),
('Carte de stationnement', 'VEHICULE', false),
('Patente', 'VEHICULE', true),

-- Documents pour les chauffeurs
('Permis de conduire', 'CHAUFFEUR', true),
('Justificatif de domicile', 'CHAUFFEUR', false),
('Contrat de travail', 'CHAUFFEUR', true);
