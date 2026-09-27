-- Deux familles de contraventions échappaient aux créances, et donc à l'arrêté
-- de compte qui compense le fonds de cotisation :
--
-- 1. La contravention sans chauffeur (relevé de l'État non rattaché, faute de
--    programme ou par ambiguïté). Personne ne la portait : la vue exigeait un
--    chauffeur_id. C'est une dette du VÉHICULE — tiers_type 'VEHICULE',
--    tiers_id = vehicule_id. Les lectures par chauffeur (balance âgée,
--    compte courant chauffeur) filtrent tiers_type = 'CHAUFFEUR' et ne la
--    voient pas ; l'axe véhicule et l'arrêté par véhicule la prennent, le fonds
--    commun des chauffeurs du véhicule la paie.
--
-- 2. La contravention reversée à l'État par l'entreprise avant que le
--    chauffeur ne l'ait remboursée. Le statut REVERSE la sortait de la vue
--    alors que l'avance restait due : l'entreprise a payé à sa place. Seule
--    l'annulation retire désormais une contravention ; c'est le restant qui
--    décide, comme pour les recettes et les pénalités. getBalanceAgeeALaDate
--    comptait déjà la reversée : la vue s'aligne sur lui.
DROP VIEW IF EXISTS v_creances_chauffeurs;

CREATE VIEW v_creances_chauffeurs AS
SELECT *
FROM (
    SELECT 'CHAUFFEUR'            AS tiers_type,
           lr.chauffeur_id        AS tiers_id,
           'ILS_ME_DOIVENT'       AS sens,
           'RECETTE'              AS document,
           lr.id                  AS document_id,
           lr.vehicule_id         AS vehicule_id,
           lr.date_recette        AS date_reference,
           lr.montant_attendu     AS montant_du,
           enc.regle              AS montant_regle,
           lr.montant_attendu - enc.regle AS restant
    FROM lignes_recette lr
    CROSS JOIN LATERAL (
        SELECT COALESCE(SUM(e.montant), 0) AS regle
        FROM encaissements e
        WHERE e.ligne_recette_id = lr.id
          AND e.annule_le IS NULL
    ) enc
    WHERE lr.statut <> 'ANNULEE'
      AND lr.annule_le IS NULL
      AND lr.chauffeur_id IS NOT NULL
      AND lr.montant_attendu IS NOT NULL
      AND lr.date_recette <= CURRENT_DATE

    UNION ALL

    SELECT 'CHAUFFEUR', lp.chauffeur_id, 'ILS_ME_DOIVENT',
           'PENALITE', lp.id, lp.vehicule_id,
           COALESCE(lp.date_faute, lp.date_generation),
           lp.montant, enc.regle,
           lp.montant - enc.regle
    FROM lignes_penalite lp
    CROSS JOIN LATERAL (
        SELECT COALESCE(SUM(e.montant), 0) AS regle
        FROM encaissements_penalite e
        WHERE e.ligne_penalite_id = lp.id
          AND e.annule_le IS NULL
    ) enc
    WHERE lp.type_sanction = 'AMENDE'
      AND lp.statut NOT IN ('ANNULEE', 'LEVEE')
      AND lp.annule_le IS NULL
      AND lp.chauffeur_id IS NOT NULL
      AND lp.montant IS NOT NULL
      AND COALESCE(lp.date_faute, lp.date_generation) <= CURRENT_DATE

    UNION ALL

    -- La contravention n'a pas de table d'encaissements : son montant_paye est
    -- la seule trace du règlement. Une contravention s'annule par annule_le, pas
    -- (seulement) par son statut : les deux sont testés.
    SELECT CASE WHEN ct.chauffeur_id IS NULL THEN 'VEHICULE' ELSE 'CHAUFFEUR' END,
           COALESCE(ct.chauffeur_id, ct.vehicule_id), 'ILS_ME_DOIVENT',
           'CONTRAVENTION', ct.id, ct.vehicule_id,
           ct.date_infraction,
           ct.montant, COALESCE(ct.montant_paye, 0),
           ct.montant - COALESCE(ct.montant_paye, 0)
    FROM contraventions ct
    WHERE COALESCE(ct.statut, 'EN_ATTENTE') <> 'ANNULE'
      AND ct.annule_le IS NULL
      AND (ct.chauffeur_id IS NOT NULL OR ct.vehicule_id IS NOT NULL)
      AND ct.montant IS NOT NULL
      AND ct.date_infraction <= CURRENT_DATE
) creances
WHERE creances.restant > 0;

-- Une ligne d'arrêté porte le débiteur de la créance qu'elle éteint. Pour une
-- dette du véhicule, il n'y en a pas : le véhicule se lit dans vehicule_id.
ALTER TABLE lignes_arrete ALTER COLUMN chauffeur_id DROP NOT NULL;
