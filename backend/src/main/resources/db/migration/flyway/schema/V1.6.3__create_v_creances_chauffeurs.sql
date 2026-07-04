-- Balance des tiers : chaque document ouvert projette une ligne
-- (dû − réglé). Colonnes tiers_type/sens prêtes pour le passif V2
-- (fournisseurs, salaires) — tout est CHAUFFEUR/ILS_ME_DOIVENT au MVP.
-- Les recettes MONTANT_REEL (montant_attendu NULL) sont exclues :
-- pas de dû chiffrable.
CREATE OR REPLACE VIEW v_creances_chauffeurs AS
SELECT 'CHAUFFEUR'            AS tiers_type,
       lr.chauffeur_id        AS tiers_id,
       'ILS_ME_DOIVENT'       AS sens,
       'RECETTE'              AS document,
       lr.id                  AS document_id,
       lr.vehicule_id         AS vehicule_id,
       lr.date_recette        AS date_reference,
       lr.montant_attendu     AS montant_du,
       lr.montant_encaisse    AS montant_regle,
       lr.montant_attendu - lr.montant_encaisse AS restant
FROM lignes_recette lr
WHERE lr.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE')
  AND lr.montant_attendu IS NOT NULL
  AND lr.montant_attendu > lr.montant_encaisse

UNION ALL

SELECT 'CHAUFFEUR', lc.chauffeur_id, 'ILS_ME_DOIVENT',
       'COTISATION', lc.id, lc.vehicule_id,
       lc.date_cotisation,
       lc.montant_du, lc.montant_encaisse,
       lc.montant_du - lc.montant_encaisse
FROM lignes_cotisation lc
WHERE lc.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE')
  AND lc.montant_du > lc.montant_encaisse

UNION ALL

SELECT 'CHAUFFEUR', lp.chauffeur_id, 'ILS_ME_DOIVENT',
       'PENALITE', lp.id, lp.vehicule_id,
       COALESCE(lp.date_faute, lp.date_generation),
       lp.montant, lp.montant_encaisse,
       lp.montant - lp.montant_encaisse
FROM lignes_penalite lp
WHERE lp.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSEE')
  AND lp.type_sanction = 'AMENDE'
  AND lp.montant > lp.montant_encaisse

UNION ALL

SELECT 'CHAUFFEUR', ct.chauffeur_id, 'ILS_ME_DOIVENT',
       'CONTRAVENTION', ct.id, ct.vehicule_id,
       ct.date_infraction,
       ct.montant, COALESCE(ct.montant_paye, 0),
       ct.montant - COALESCE(ct.montant_paye, 0)
FROM contraventions ct
WHERE ct.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_PAYE')
  AND ct.chauffeur_id IS NOT NULL
  AND ct.montant IS NOT NULL
  AND ct.montant > COALESCE(ct.montant_paye, 0);
