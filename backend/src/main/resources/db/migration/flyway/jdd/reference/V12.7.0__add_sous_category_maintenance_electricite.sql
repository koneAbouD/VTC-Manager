-- Ajout de la sous-catégorie "Maintenance" pour la catégorie "Electricite"
INSERT INTO sous_categories_operation (code, libelle, categorie_id, actif)
VALUES ('SC_ELECTRICITE', 'Maintenance', (SELECT id FROM categories_operation WHERE code = 'ELECTRICITE'), TRUE)
ON CONFLICT (code) DO NOTHING;
