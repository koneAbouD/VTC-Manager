-- Paramètre global : durée d'amortissement linéaire des véhicules, en mois.
-- 60 = 5 ans. Surchargeable par véhicule (colonne vehicules.duree_amortissement_mois).
INSERT INTO parametres_generaux (cle, valeur, libelle, description, created_at, updated_at)
VALUES ('DUREE_AMORTISSEMENT_MOIS', '60',
        'Durée d''amortissement des véhicules (mois)',
        'Durée d''amortissement linéaire par défaut appliquée à toute la flotte, en mois (60 = 5 ans). Peut être surchargée individuellement au niveau d''un véhicule.',
        now(), now())
ON CONFLICT (cle) DO NOTHING;
