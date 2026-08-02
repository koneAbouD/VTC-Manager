-- Remboursement, par le responsable, d'un écart de caisse imputé RECOUVREE.
--
-- L'encaissement de ce remboursement n'est pas un produit : c'est l'extinction
-- de la créance née de l'imputation. Sans catégorie dédiée HORS_RESULTAT, il
-- serait saisi en recette ordinaire et gonflerait le résultat d'un montant qui
-- ne fait que réparer un manquant.
INSERT INTO categories_operation (code, libelle, type_operation, actif, nature_resultat) VALUES
    ('ECART_CAISSE_REMBOURSEMENT', 'Remboursement d''écart de caisse', 'REVENU', TRUE, 'HORS_RESULTAT')
ON CONFLICT (code) DO NOTHING;
