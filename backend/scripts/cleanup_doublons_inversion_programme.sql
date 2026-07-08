-- ============================================================================
-- Nettoyage des doublons recette / cotisation / pénalité créés à tort après
-- une INVERSION RÉTROACTIVE du programme des chauffeurs (alternance automatique)
-- ----------------------------------------------------------------------------
-- Contexte : en alternance AUTOMATIQUE (2 chauffeurs, 1 seul conducteur/jour),
-- inverser le programme change le chauffeur actif d'une date déjà passée. Si le
-- chauffeur d'origine avait déjà encaissé, la (re)génération créait une ligne
-- « fantôme » EN_ATTENTE pour le nouveau chauffeur → doublon de recette /
-- cotisation, et une pénalité RECETTE_NON_VERSEE rattachée. Le code est corrigé
-- (dejaHonoreParChauffeurRetire) : ce script ne nettoie QUE l'historique déjà
-- pollué.
--
-- Signature du doublon-fantôme (toutes les conditions doivent être vraies) :
--   1. véhicule en alternance AUTOMATIQUE avec 2 chauffeurs autorisés
--      (le seul mode où un 2e conducteur le même jour est forcément un fantôme ;
--       en mode MANUEL/jour partagé, 2 chauffeurs peuvent légitimement devoir)
--   2. ligne EN_ATTENTE, montant_encaisse = 0, aucun encaissement rattaché
--   3. un AUTRE chauffeur a, le même jour sur le même véhicule, une ligne
--      réellement encaissée (statut encaissé OU montant_encaisse > 0)
--
-- Utilisation :
--   1) Lancer la PARTIE 1 (DRY-RUN) et vérifier les lignes listées.
--   2) Si OK, décommenter et lancer la PARTIE 2 (transaction + COMMIT).
--
--   psql -h $DB_HOST -U $DB_USER -d vtc_manager \
--        -v date_cible=ALL \
--        -f cleanup_doublons_inversion_programme.sql
--
--   date_cible = ALL  → balaye toutes les dates (défaut)
--   date_cible = 2026-07-06 → restreint à cette seule date
-- ============================================================================

\set ON_ERROR_STOP on

\if :{?date_cible}
\else
  \set date_cible ALL
\endif


-- ============================================================================
-- PARTIE 1 — DRY-RUN (lecture seule) : ce qui sera supprimé
-- ============================================================================

\echo '--- Recettes fantômes candidates à la suppression ---'
SELECT lr.id, lr.vehicule_id, lr.chauffeur_id, lr.date_recette,
       lr.montant_attendu, lr.montant_encaisse, lr.statut, lr.created_at
FROM lignes_recette lr
JOIN vehicule_programmes vp ON vp.vehicule_id = lr.vehicule_id
WHERE vp.mode_alternance = 'AUTOMATIQUE'
  AND vp.nombre_chauffeurs_autorises = 2
  AND lr.statut = 'EN_ATTENTE'
  AND lr.montant_encaisse = 0
  AND (:'date_cible' = 'ALL' OR lr.date_recette::text = :'date_cible')
  AND NOT EXISTS (SELECT 1 FROM encaissements e WHERE e.ligne_recette_id = lr.id)
  AND EXISTS (
        SELECT 1 FROM lignes_recette m
        WHERE m.vehicule_id = lr.vehicule_id
          AND m.date_recette = lr.date_recette
          AND m.chauffeur_id <> lr.chauffeur_id
          AND m.statut <> 'ANNULEE'
          AND (m.montant_encaisse > 0
               OR m.statut IN ('PARTIELLEMENT_ENCAISSE', 'ENCAISSE')))
ORDER BY lr.vehicule_id, lr.date_recette, lr.chauffeur_id;

\echo '--- Pénalités rattachées à ces recettes fantômes (seront supprimées d''abord) ---'
SELECT lp.id, lp.vehicule_id, lp.chauffeur_id, lp.date_faute,
       lp.type_penalite, lp.montant, lp.montant_encaisse, lp.statut, lp.ligne_recette_id
FROM lignes_penalite lp
WHERE lp.statut = 'EN_ATTENTE'
  AND lp.montant_encaisse = 0
  AND NOT EXISTS (SELECT 1 FROM encaissements_penalite ep WHERE ep.ligne_penalite_id = lp.id)
  AND lp.ligne_recette_id IN (
        SELECT lr.id
        FROM lignes_recette lr
        JOIN vehicule_programmes vp ON vp.vehicule_id = lr.vehicule_id
        WHERE vp.mode_alternance = 'AUTOMATIQUE'
          AND vp.nombre_chauffeurs_autorises = 2
          AND lr.statut = 'EN_ATTENTE'
          AND lr.montant_encaisse = 0
          AND (:'date_cible' = 'ALL' OR lr.date_recette::text = :'date_cible')
          AND NOT EXISTS (SELECT 1 FROM encaissements e WHERE e.ligne_recette_id = lr.id)
          AND EXISTS (
                SELECT 1 FROM lignes_recette m
                WHERE m.vehicule_id = lr.vehicule_id
                  AND m.date_recette = lr.date_recette
                  AND m.chauffeur_id <> lr.chauffeur_id
                  AND m.statut <> 'ANNULEE'
                  AND (m.montant_encaisse > 0
                       OR m.statut IN ('PARTIELLEMENT_ENCAISSE', 'ENCAISSE'))))
ORDER BY lp.vehicule_id, lp.date_faute, lp.chauffeur_id;

\echo '--- Cotisations fantômes candidates à la suppression ---'
SELECT lc.id, lc.vehicule_id, lc.chauffeur_id, lc.date_cotisation,
       lc.nom_cotisation, lc.montant_du, lc.montant_encaisse, lc.statut, lc.created_at
FROM lignes_cotisation lc
JOIN vehicule_programmes vp ON vp.vehicule_id = lc.vehicule_id
WHERE vp.mode_alternance = 'AUTOMATIQUE'
  AND vp.nombre_chauffeurs_autorises = 2
  AND lc.statut = 'EN_ATTENTE'
  AND lc.montant_encaisse = 0
  AND (:'date_cible' = 'ALL' OR lc.date_cotisation::text = :'date_cible')
  AND NOT EXISTS (SELECT 1 FROM encaissements_cotisation ec WHERE ec.ligne_cotisation_id = lc.id)
  AND EXISTS (
        SELECT 1 FROM lignes_cotisation m
        WHERE m.vehicule_id = lc.vehicule_id
          AND m.date_cotisation = lc.date_cotisation
          AND m.chauffeur_id <> lc.chauffeur_id
          AND m.statut <> 'ANNULEE'
          AND (m.montant_encaisse > 0
               OR m.statut IN ('PARTIELLEMENT_ENCAISSE', 'ENCAISSE')))
ORDER BY lc.vehicule_id, lc.date_cotisation, lc.chauffeur_id, lc.nom_cotisation;


-- ============================================================================
-- PARTIE 2 — SUPPRESSION (transactionnelle)
-- ----------------------------------------------------------------------------
-- Décommentez ce bloc UNIQUEMENT après avoir validé le DRY-RUN ci-dessus.
-- Ordre imposé par les clés étrangères : pénalités → recettes, puis cotisations.
-- ============================================================================

-- BEGIN;
--
-- -- Jeu des recettes fantômes, matérialisé pour être réutilisé.
-- CREATE TEMP TABLE tmp_recette_fantomes ON COMMIT DROP AS
-- SELECT lr.id
-- FROM lignes_recette lr
-- JOIN vehicule_programmes vp ON vp.vehicule_id = lr.vehicule_id
-- WHERE vp.mode_alternance = 'AUTOMATIQUE'
--   AND vp.nombre_chauffeurs_autorises = 2
--   AND lr.statut = 'EN_ATTENTE'
--   AND lr.montant_encaisse = 0
--   AND (:'date_cible' = 'ALL' OR lr.date_recette::text = :'date_cible')
--   AND NOT EXISTS (SELECT 1 FROM encaissements e WHERE e.ligne_recette_id = lr.id)
--   AND EXISTS (
--         SELECT 1 FROM lignes_recette m
--         WHERE m.vehicule_id = lr.vehicule_id
--           AND m.date_recette = lr.date_recette
--           AND m.chauffeur_id <> lr.chauffeur_id
--           AND m.statut <> 'ANNULEE'
--           AND (m.montant_encaisse > 0
--                OR m.statut IN ('PARTIELLEMENT_ENCAISSE', 'ENCAISSE')));
--
-- -- 1) Pénalités non encaissées rattachées à ces recettes fantômes.
-- WITH supprimees AS (
--     DELETE FROM lignes_penalite lp
--     WHERE lp.ligne_recette_id IN (SELECT id FROM tmp_recette_fantomes)
--       AND lp.statut = 'EN_ATTENTE'
--       AND lp.montant_encaisse = 0
--       AND NOT EXISTS (SELECT 1 FROM encaissements_penalite ep WHERE ep.ligne_penalite_id = lp.id)
--     RETURNING lp.id
-- )
-- SELECT count(*) AS penalites_supprimees FROM supprimees;
--
-- -- 2) Recettes fantômes (seulement si plus aucune pénalité ne les référence).
-- WITH supprimees AS (
--     DELETE FROM lignes_recette lr
--     WHERE lr.id IN (SELECT id FROM tmp_recette_fantomes)
--       AND NOT EXISTS (SELECT 1 FROM lignes_penalite p WHERE p.ligne_recette_id = lr.id)
--     RETURNING lr.id
-- )
-- SELECT count(*) AS recettes_supprimees FROM supprimees;
--
-- -- 3) Cotisations fantômes.
-- WITH supprimees AS (
--     DELETE FROM lignes_cotisation lc
--     USING vehicule_programmes vp
--     WHERE vp.vehicule_id = lc.vehicule_id
--       AND vp.mode_alternance = 'AUTOMATIQUE'
--       AND vp.nombre_chauffeurs_autorises = 2
--       AND lc.statut = 'EN_ATTENTE'
--       AND lc.montant_encaisse = 0
--       AND (:'date_cible' = 'ALL' OR lc.date_cotisation::text = :'date_cible')
--       AND NOT EXISTS (SELECT 1 FROM encaissements_cotisation ec WHERE ec.ligne_cotisation_id = lc.id)
--       AND EXISTS (
--             SELECT 1 FROM lignes_cotisation m
--             WHERE m.vehicule_id = lc.vehicule_id
--               AND m.date_cotisation = lc.date_cotisation
--               AND m.chauffeur_id <> lc.chauffeur_id
--               AND m.statut <> 'ANNULEE'
--               AND (m.montant_encaisse > 0
--                    OR m.statut IN ('PARTIELLEMENT_ENCAISSE', 'ENCAISSE')))
--     RETURNING lc.id
-- )
-- SELECT count(*) AS cotisations_supprimees FROM supprimees;
--
-- -- Vérifiez les compteurs ci-dessus, puis :
-- COMMIT;    -- ou ROLLBACK; pour annuler
