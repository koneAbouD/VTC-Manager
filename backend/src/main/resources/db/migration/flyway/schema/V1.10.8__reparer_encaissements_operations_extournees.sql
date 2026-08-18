-- Répare les encaissements laissés par l'extourne d'une écriture.
--
-- L'annulation marquait l'encaissement puis le confiait au dépôt, dont le
-- save() reconstruisait une entité sans identifiant : au lieu de corriger le
-- versement, il en insérait un second, actif. Le recalcul de la ligne sommait
-- alors les deux — le montant encaissé doublait quand il aurait dû tomber, et
-- la créance restait soldée alors que le versement avait été annulé.
--
-- Trois temps, pour chacune des trois familles (recette, cotisation,
-- pénalité) :
--   1. supprimer les doublons — une écriture ne porte qu'un encaissement, le
--      surnuméraire n'a jamais eu d'existence légitime ; on garde le premier ;
--   2. marquer annulés les encaissements des écritures extournées, en
--      reprenant l'auteur et le motif portés par l'écriture ;
--   3. recalculer montant encaissé et statut des lignes touchées, aux mêmes
--      conditions que le code applicatif (une ligne annulée ou restituée n'est
--      pas retouchée).

-- ── 1. Doublons ─────────────────────────────────────────────────────────────
DELETE FROM encaissements e
 USING operations_financieres o
 WHERE e.operation_financiere_id = o.id
   AND o.annule_le IS NOT NULL
   AND e.id > (SELECT MIN(e2.id) FROM encaissements e2
                WHERE e2.operation_financiere_id = e.operation_financiere_id);

DELETE FROM encaissements_cotisation e
 USING operations_financieres o
 WHERE e.operation_financiere_id = o.id
   AND o.annule_le IS NOT NULL
   AND e.id > (SELECT MIN(e2.id) FROM encaissements_cotisation e2
                WHERE e2.operation_financiere_id = e.operation_financiere_id);

DELETE FROM encaissements_penalite e
 USING operations_financieres o
 WHERE e.operation_financiere_id = o.id
   AND o.annule_le IS NOT NULL
   AND e.id > (SELECT MIN(e2.id) FROM encaissements_penalite e2
                WHERE e2.operation_financiere_id = e.operation_financiere_id);

-- ── 2. Marquage d'annulation ────────────────────────────────────────────────
UPDATE encaissements e
   SET annule_le = o.annule_le,
       annule_par = o.annule_par,
       motif_annulation = o.motif_annulation
  FROM operations_financieres o
 WHERE e.operation_financiere_id = o.id
   AND o.annule_le IS NOT NULL
   AND e.annule_le IS NULL;

UPDATE encaissements_cotisation e
   SET annule_le = o.annule_le,
       annule_par = o.annule_par,
       motif_annulation = o.motif_annulation
  FROM operations_financieres o
 WHERE e.operation_financiere_id = o.id
   AND o.annule_le IS NOT NULL
   AND e.annule_le IS NULL;

UPDATE encaissements_penalite e
   SET annule_le = o.annule_le,
       annule_par = o.annule_par,
       motif_annulation = o.motif_annulation
  FROM operations_financieres o
 WHERE e.operation_financiere_id = o.id
   AND o.annule_le IS NOT NULL
   AND e.annule_le IS NULL;

-- ── 3. Recalcul des lignes touchées ─────────────────────────────────────────
UPDATE lignes_recette lr
   SET montant_encaisse = sub.total,
       statut = CASE
           WHEN lr.montant_attendu IS NULL
               THEN CASE WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSE' ELSE 'EN_ATTENTE' END
           WHEN sub.total >= lr.montant_attendu THEN 'ENCAISSE'
           WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSE'
           ELSE 'EN_ATTENTE'
       END
  FROM (SELECT ligne_recette_id,
               COALESCE(SUM(montant) FILTER (WHERE annule_le IS NULL), 0) AS total
          FROM encaissements
         GROUP BY ligne_recette_id) sub
 WHERE lr.id = sub.ligne_recette_id
   AND lr.statut <> 'ANNULEE'
   AND lr.montant_encaisse IS DISTINCT FROM sub.total;

UPDATE lignes_cotisation lc
   SET montant_encaisse = sub.total,
       statut = CASE
           WHEN sub.total >= lc.montant_du THEN 'ENCAISSE'
           WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSE'
           ELSE 'EN_ATTENTE'
       END
  FROM (SELECT ligne_cotisation_id,
               COALESCE(SUM(montant) FILTER (WHERE annule_le IS NULL), 0) AS total
          FROM encaissements_cotisation
         GROUP BY ligne_cotisation_id) sub
 WHERE lc.id = sub.ligne_cotisation_id
   AND lc.statut NOT IN ('ANNULEE', 'RESTITUEE')
   AND lc.montant_encaisse IS DISTINCT FROM sub.total;

UPDATE lignes_penalite lp
   SET montant_encaisse = sub.total,
       statut = CASE
           WHEN sub.total >= lp.montant THEN 'ENCAISSEE'
           WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSEE'
           ELSE 'EN_ATTENTE'
       END
  FROM (SELECT ligne_penalite_id,
               COALESCE(SUM(montant) FILTER (WHERE annule_le IS NULL), 0) AS total
          FROM encaissements_penalite
         GROUP BY ligne_penalite_id) sub
 WHERE lp.id = sub.ligne_penalite_id
   AND lp.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSEE', 'ENCAISSEE')
   AND lp.montant_encaisse IS DISTINCT FROM sub.total;
