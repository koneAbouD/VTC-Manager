-- Charges directes du véhicule, et réparation de deux catégories mal classées.
--
-- 1) Vignette et Taxe sont des DÉPENSES, mais elles ont été insérées (V13.4.0)
--    après la pose du DEFAULT 'PRODUIT_EXPLOITATION' (V1.6.2) sans nature
--    explicite : elles l'ont donc hérité. Une vignette payée sur un véhicule
--    s'ajoutait à ses produits au lieu d'être déduite de ses charges — l'écart
--    sur sa marge valait deux fois le montant payé. On les reclasse, on retire
--    le DEFAULT qui a rendu l'accident possible, et on pose la contrainte qui
--    l'empêche de se reproduire : une dépense n'est jamais un produit.
--
-- 2) « Charge fixe » recouvrait deux choses que la marge par véhicule ne peut
--    pas traiter de la même façon : les charges de structure (publicité, frais
--    bancaires, formation), qui ne se rattachent à aucun véhicule, et les
--    charges directes du véhicule — assurance, vignette, patente, visite
--    technique, carte de stationnement — fixes dans le mois mais parfaitement
--    traçables, saisies avec leur vehicule_id. Ces dernières n'entraient dans
--    aucune marge : un véhicule assuré 176 800 sur le mois s'affichait au même
--    rang qu'un véhicule qui n'avait rien coûté. Le drapeau les distingue sans
--    toucher à la cascade du compte de résultat, où elles restent des charges
--    fixes.

ALTER TABLE categories_operation
    ADD COLUMN IF NOT EXISTS imputable_vehicule BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN categories_operation.imputable_vehicule IS
    'Charge fixe directement rattachable à un véhicule (assurance, documents) : '
    'déduite de sa marge après coûts variables, sans quitter les charges fixes '
    'du compte de résultat.';

-- Réparation avant contrainte : ces deux-là la violeraient.
UPDATE categories_operation
   SET nature_resultat = 'CHARGE_FIXE'
 WHERE code IN ('VIGNETTE', 'TAXE')
   AND type_operation = 'DEPENSE'
   AND nature_resultat = 'PRODUIT_EXPLOITATION';

-- Le défaut qui a causé l'erreur : toute catégorie créée sans nature explicite
-- devenait un produit d'exploitation, dépense comprise.
ALTER TABLE categories_operation
    ALTER COLUMN nature_resultat DROP DEFAULT;

-- Un revenu ne peut pas être une charge, une dépense ne peut pas être un
-- produit. HORS_RESULTAT reste ouvert aux deux : les comptes de tiers
-- (cotisations, contraventions refacturées, écarts de caisse) ont les deux sens.
ALTER TABLE categories_operation
    DROP CONSTRAINT IF EXISTS chk_categories_operation_sens;
ALTER TABLE categories_operation
    ADD CONSTRAINT chk_categories_operation_sens CHECK (
        nature_resultat = 'HORS_RESULTAT'
        OR (type_operation = 'REVENU'  AND nature_resultat = 'PRODUIT_EXPLOITATION')
        OR (type_operation = 'DEPENSE' AND nature_resultat IN ('CHARGE_VARIABLE', 'CHARGE_FIXE'))
    );

-- Le groupe « Documents » au complet : ce qu'un véhicule coûte pour rouler
-- légalement, indépendamment de son kilométrage.
UPDATE categories_operation
   SET imputable_vehicule = TRUE
 WHERE code IN ('ASSURANCE', 'VISITE_TECHNIQUE', 'PATENTE',
                'CARTE_STATIONNEMENT', 'VIGNETTE', 'TAXE');
