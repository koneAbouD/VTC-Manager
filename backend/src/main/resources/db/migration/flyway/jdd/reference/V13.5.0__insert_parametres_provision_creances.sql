-- Politique de dépréciation des créances chauffeurs, par tranche d'ancienneté.
--
-- Les créances entraient au bilan pour leur valeur brute : sur ce métier, une
-- somme due depuis plus d'un mois par un chauffeur qui a quitté le parc n'est
-- que rarement recouvrée. Les taux ci-dessous sont un point de départ prudent,
-- à caler avec le cabinet comptable ; ils sont modifiables sans redéploiement.
INSERT INTO parametres_generaux (cle, valeur, libelle, description, created_at, updated_at)
VALUES
    ('PROVISION_CREANCES_TAUX_0_7', '0',
     'Provision créances 0-7 jours (%)',
     'Taux de dépréciation appliqué aux créances de moins de 8 jours. 0 par défaut : une créance récente est présumée recouvrable.',
     now(), now()),
    ('PROVISION_CREANCES_TAUX_8_30', '25',
     'Provision créances 8-30 jours (%)',
     'Taux de dépréciation appliqué aux créances de 8 à 30 jours.',
     now(), now()),
    ('PROVISION_CREANCES_TAUX_PLUS_30', '50',
     'Provision créances de plus de 30 jours (%)',
     'Taux de dépréciation appliqué aux créances de plus de 30 jours. À relever si le recouvrement au-delà de ce délai s''avère exceptionnel.',
     now(), now())
ON CONFLICT (cle) DO NOTHING;
