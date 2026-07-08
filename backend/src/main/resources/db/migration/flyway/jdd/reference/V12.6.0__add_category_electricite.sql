-- Ajout de la catégorie "Electricite" pour les dépenses
INSERT INTO categories_operation (code, libelle, type_operation, actif)
VALUES ('ELECTRICITE', 'Electricité', 'DEPENSE', TRUE)
ON CONFLICT (code) DO NOTHING;
