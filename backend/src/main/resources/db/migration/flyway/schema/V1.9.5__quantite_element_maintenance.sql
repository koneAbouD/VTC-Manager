-- Une ligne d'intervention peut porter plusieurs exemplaires du même élément.
--
-- Jusqu'ici « Pneu avant » ne se saisissait qu'une fois, à un montant global :
-- pour quatre pneus, il fallait soit répéter la ligne, soit taper le total de
-- tête. Aucun des deux ne disait ce qui avait vraiment été posé, et le prix
-- unitaire du catalogue ne servait plus à rien dès qu'on dépassait l'unité.
--
-- La ligne porte donc sa quantité. `montant` reste le TOTAL de la ligne
-- (quantité × prix unitaire) : tout ce qui somme les éléments — coût de
-- l'intervention, répartition des dettes entre partenaires — continue de lire
-- la même colonne sans rien changer. Le prix unitaire n'est pas stocké, il se
-- retrouve par division ; le dupliquer ouvrirait la porte à deux vérités.

ALTER TABLE elements_maintenance
    ADD COLUMN IF NOT EXISTS quantite INTEGER NOT NULL DEFAULT 1;

-- Les lignes déjà saisies valaient un exemplaire : le DEFAULT les a servies.
-- Une quantité nulle ou négative n'a pas de sens et fausserait le prix
-- unitaire recalculé (division par zéro).
ALTER TABLE elements_maintenance DROP CONSTRAINT IF EXISTS ck_elements_maintenance_quantite;
ALTER TABLE elements_maintenance
    ADD CONSTRAINT ck_elements_maintenance_quantite CHECK (quantite > 0);
