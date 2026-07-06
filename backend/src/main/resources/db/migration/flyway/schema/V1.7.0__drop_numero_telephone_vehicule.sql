-- Suppression du champ « Tél. véhicule » : la colonne n'est plus mappée ni
-- exposée par l'API (retirée du domaine, des DTOs et de l'entité). On la
-- supprime définitivement de la table.
ALTER TABLE vehicules DROP COLUMN IF EXISTS numero_telephone_vehicule;
