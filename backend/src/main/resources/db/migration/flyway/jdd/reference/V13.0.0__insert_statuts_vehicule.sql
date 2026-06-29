-- Jeu de données des statuts de véhicule (libellé, signification, couleur)
INSERT INTO statuts_vehicule (code, libelle, signification, couleur, ordre, created_at, updated_at) VALUES
('EN_SERVICE',     'En service',     'Affecté à un chauffeur, en exploitation',          '#22C55E', 1, NOW(), NOW()),
('DISPONIBLE',     'Disponible',     'Opérationnel mais sans chauffeur affecté',         '#3B82F6', 2, NOW(), NOW()),
('EN_MAINTENANCE', 'En maintenance', 'Immobilisé pour entretien/réparation',             '#F97316', 3, NOW(), NOW()),
('IMMOBILISE',     'Immobilisé',     'Panne, accident, saisie, contravention bloquante', '#EF4444', 4, NOW(), NOW()),
('HORS_PARC',      'Hors parc',      'Vendu, réformé, restitué (leasing)',               '#6B7280', 5, NOW(), NOW());
