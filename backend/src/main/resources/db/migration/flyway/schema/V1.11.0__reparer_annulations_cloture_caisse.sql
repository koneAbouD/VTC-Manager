-- Répare ce que le retrait d'un relevé de caisse laissait derrière lui.
--
-- Deux séquelles, l'une comptable, l'autre d'affichage :
--
--   1. L'ajustement d'écart était contre-passé au jour de l'annulation, alors
--      qu'il n'existait que pour faire coller le solde à une journée précise.
--      Le couple ne s'annulait donc qu'à partir du jour du retrait : le solde
--      théorique de la journée comptée restait faussé du montant de l'écart,
--      et son recomptage butait sur un écart que plus rien ne justifiait —
--      exigeant un motif que l'écran, se croyant juste, n'affichait même pas.
--
--   2. Le relevé retiré gardait son écart « EN_ATTENTE » d'imputation, alors
--      que l'écart n'a plus d'existence et que son ajustement est contre-passé.
--      Personne n'a plus à trancher entre perte et recouvrement.

-- ── 1. Extournes d'ajustement redatées sur leur écriture d'origine ──────────
--
-- Deux garde-fous, parce qu'une date d'écriture ne se change pas à la légère :
--   • jamais dans un mois déjà clôturé — les états publiés de ce mois ne
--     doivent pas bouger sous les pieds de qui les a servis ;
--   • jamais d'une année sur l'autre — la référence EXT-AAAA-NNNNNN porte son
--     millésime, et la déplacer la ferait mentir.
-- Les cas ainsi laissés de côté restent lisibles au journal, avec leur
-- écriture d'origine : ils se corrigent à la main, s'il y en a.
UPDATE operations_financieres ext
   SET date_operation = origine.date_operation
  FROM operations_financieres origine
 WHERE ext.extourne_de_id = origine.id
   AND origine.reference LIKE 'CLO-%'
   AND ext.date_operation <> origine.date_operation
   AND EXTRACT(YEAR FROM ext.date_operation) = EXTRACT(YEAR FROM origine.date_operation)
   AND origine.date_operation > COALESCE(
           (SELECT (make_date(annee, mois, 1) + INTERVAL '1 month - 1 day')::date
              FROM clotures_periode
             ORDER BY annee DESC, mois DESC
             LIMIT 1),
           DATE '1900-01-01');

-- ── 2. Écarts de relevés retirés : plus rien à imputer ──────────────────────
--
-- Seul l'état d'attente est effacé. Un écart déjà tranché (PERTE, RECOUVREE)
-- n'est pas concerné : son imputation a produit des écritures, et le retrait
-- d'un tel relevé est de toute façon refusé tant qu'elles ne sont pas
-- extournées.
UPDATE clotures_caisse
   SET imputation_statut = NULL
 WHERE annule_le IS NOT NULL
   AND imputation_statut = 'EN_ATTENTE';
