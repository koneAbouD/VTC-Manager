-- ============================================================================
-- Rollback des recettes / cotisations générées à tort le jour de salaire
-- ----------------------------------------------------------------------------
-- Contexte : dimanche 2026-07-05 était un jour de salaire, mais les schedulers
-- du lundi matin (06:00 recettes, 06:05 cotisations) ont quand même généré des
-- lignes. Ce script supprime uniquement ces lignes indûment créées.
--
-- Sécurités appliquées (une ligne n'est supprimée QUE si TOUTES sont vraies) :
--   1. date = le jour de salaire ciblé (:date_cible)
--   2. statut = 'EN_ATTENTE'            → jamais une ligne partiellement encaissée
--   3. montant_encaisse = 0             → aucun argent enregistré
--   4. aucun encaissement rattaché      → double sécurité (NOT EXISTS)
--   5. le véhicule a bien DIMANCHE comme jour de salaire actif
--   6. ligne créée aujourd'hui (créée ce matin par le scheduler)
--
-- Utilisation :
--   1) Lancer d'abord la PARTIE 1 (DRY-RUN) pour vérifier ce qui sera supprimé.
--   2) Si le résultat est correct, lancer la PARTIE 2 (transaction + COMMIT).
--
--   psql -h $DB_HOST -U $DB_USER -d vtc_manager \
--        -v date_cible=2026-07-05 \
--        -f rollback_jour_salaire_2026-07-05.sql
--
-- Date passée SANS quotes ; le script la quote lui-même (:'date_cible').
-- Par défaut, date_cible vaut 2026-07-05 si non fourni en ligne de commande.
-- ============================================================================

\set ON_ERROR_STOP on

-- Valeur par défaut si -v date_cible n'est pas passé en ligne de commande
\if :{?date_cible}
\else
  \set date_cible 2026-07-05
\endif


-- ============================================================================
-- PARTIE 1 — DRY-RUN (lecture seule) : ce qui sera supprimé
-- ============================================================================

\echo '--- Recettes candidates à la suppression ---'
SELECT lr.id, lr.vehicule_id, lr.chauffeur_id, lr.date_recette,
       lr.montant_attendu, lr.montant_encaisse, lr.statut, lr.created_at
FROM lignes_recette lr
JOIN vehicule_programmes vp ON vp.vehicule_id = lr.vehicule_id
WHERE lr.date_recette = DATE :'date_cible'
  AND lr.statut = 'EN_ATTENTE'
  AND lr.montant_encaisse = 0
  AND vp.jour_salaire_actif = true
  AND vp.jour_salaire = 'DIMANCHE'
  AND lr.created_at::date = CURRENT_DATE
  AND NOT EXISTS (SELECT 1 FROM encaissements e WHERE e.ligne_recette_id = lr.id)
ORDER BY lr.vehicule_id, lr.chauffeur_id;

\echo '--- Cotisations candidates à la suppression ---'
SELECT lc.id, lc.vehicule_id, lc.chauffeur_id, lc.date_cotisation,
       lc.nom_cotisation, lc.montant_du, lc.montant_encaisse, lc.statut, lc.created_at
FROM lignes_cotisation lc
JOIN vehicule_programmes vp ON vp.vehicule_id = lc.vehicule_id
WHERE lc.date_cotisation = DATE :'date_cible'
  AND lc.statut = 'EN_ATTENTE'
  AND lc.montant_encaisse = 0
  AND vp.jour_salaire_actif = true
  AND vp.jour_salaire = 'DIMANCHE'
  AND lc.created_at::date = CURRENT_DATE
  AND NOT EXISTS (SELECT 1 FROM encaissements_cotisation ec WHERE ec.ligne_cotisation_id = lc.id)
ORDER BY lc.vehicule_id, lc.chauffeur_id, lc.nom_cotisation;


-- ============================================================================
-- PARTIE 2 — SUPPRESSION (transactionnelle)
-- ----------------------------------------------------------------------------
-- Décommentez ce bloc UNIQUEMENT après avoir validé le DRY-RUN ci-dessus.
-- ============================================================================

-- BEGIN;
--
-- WITH supprimees AS (
--     DELETE FROM lignes_recette lr
--     USING vehicule_programmes vp
--     WHERE vp.vehicule_id = lr.vehicule_id
--       AND lr.date_recette = DATE :'date_cible'
--       AND lr.statut = 'EN_ATTENTE'
--       AND lr.montant_encaisse = 0
--       AND vp.jour_salaire_actif = true
--       AND vp.jour_salaire = 'DIMANCHE'
--       AND lr.created_at::date = CURRENT_DATE
--       AND NOT EXISTS (SELECT 1 FROM encaissements e WHERE e.ligne_recette_id = lr.id)
--     RETURNING lr.id
-- )
-- SELECT count(*) AS recettes_supprimees FROM supprimees;
--
-- WITH supprimees AS (
--     DELETE FROM lignes_cotisation lc
--     USING vehicule_programmes vp
--     WHERE vp.vehicule_id = lc.vehicule_id
--       AND lc.date_cotisation = DATE :'date_cible'
--       AND lc.statut = 'EN_ATTENTE'
--       AND lc.montant_encaisse = 0
--       AND vp.jour_salaire_actif = true
--       AND vp.jour_salaire = 'DIMANCHE'
--       AND lc.created_at::date = CURRENT_DATE
--       AND NOT EXISTS (SELECT 1 FROM encaissements_cotisation ec WHERE ec.ligne_cotisation_id = lc.id)
--     RETURNING lc.id
-- )
-- SELECT count(*) AS cotisations_supprimees FROM supprimees;
--
-- -- Vérifiez les compteurs ci-dessus, puis :
-- COMMIT;    -- ou ROLLBACK; pour annuler
