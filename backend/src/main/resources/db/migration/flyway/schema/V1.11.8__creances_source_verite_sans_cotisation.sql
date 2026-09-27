-- La balance âgée affichait des débiteurs qui ne devaient rien et des montants
-- faux. Trois défauts de v_creances_chauffeurs, corrigés ensemble :
--
-- 1. Le restant se lisait sur montant_encaisse et le statut, deux colonnes
--    dénormalisées. Elles décrochent dès qu'un chemin oublie le recalcul — la
--    régénération, par exemple, réécrit montant_attendu sans toucher au statut :
--    une ligne ENCAISSE dont le dû a augmenté sortait de la vue, une ligne restée
--    PARTIELLEMENT_ENCAISSE après une baisse y restait. Le réglé se recompte
--    désormais sur les encaissements non annulés, et c'est le seul restant > 0
--    qui décide de la présence d'une ligne ; le statut ne sert plus qu'à écarter
--    ce qui a été annulé (ou levé, pour une pénalité).
--
-- 2. Une ligne générée pour une date à venir (génération manuelle sur une date
--    future) était déjà comptée comme due. Seul ce qui est échu entre dans la
--    balance : date de référence au plus tard aujourd'hui.
--
-- 3. La cotisation non versée y figurait comme une dette. C'est l'épargne du
--    chauffeur, jamais compensée par un arrêté : les comptes courants et le
--    calcul d'arrêté l'écartaient déjà chacun de leur côté. La vue ne la porte
--    plus, et tous ses lecteurs (balance âgée, bilan, provisions) s'alignent.
--
-- DROP puis CREATE plutôt que CREATE OR REPLACE : les colonnes calculées
-- changent de typmod (numeric(19,2) → numeric), ce que REPLACE refuse.
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
    -- la seule trace du règlement.
    SELECT 'CHAUFFEUR', ct.chauffeur_id, 'ILS_ME_DOIVENT',
           'CONTRAVENTION', ct.id, ct.vehicule_id,
           ct.date_infraction,
           ct.montant, COALESCE(ct.montant_paye, 0),
           ct.montant - COALESCE(ct.montant_paye, 0)
    FROM contraventions ct
    WHERE ct.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_PAYE')
      AND ct.annule_le IS NULL
      AND ct.chauffeur_id IS NOT NULL
      AND ct.montant IS NOT NULL
      AND ct.date_infraction <= CURRENT_DATE
) creances
WHERE creances.restant > 0;
