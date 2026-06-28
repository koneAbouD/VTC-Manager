-- Insertion des données de test pour les types de documents
-- Jeux de Données de Test (JDD)

INSERT INTO types_document (nom, cible, obligatoire) VALUES
-- Documents pour les véhicules
('Carte grise', 'VEHICULE', true),
('Assurance véhicule', 'VEHICULE', true),
('Contrôle technique', 'VEHICULE', true),
('Vignette Crit''Air', 'VEHICULE', false),
('Autorisation de stationnement', 'VEHICULE', false),

-- Documents pour les chauffeurs
('Permis de conduire', 'CHAUFFEUR', true),
('Carte professionnelle de transport', 'CHAUFFEUR', true),
('Visite médicale', 'CHAUFFEUR', true),
('Attestation de formation', 'CHAUFFEUR', false),
('Justificatif de domicile', 'CHAUFFEUR', false),
('RIB', 'CHAUFFEUR', false),
('Contrat de travail', 'CHAUFFEUR', true);
