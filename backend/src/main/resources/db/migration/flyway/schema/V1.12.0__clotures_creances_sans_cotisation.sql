-- Les photos de clôture prises avant V1.11.8 comptaient la cotisation non versée
-- parmi les créances chauffeurs : getBalanceAgeeALaDate l'incluait alors. Or une
-- cotisation non versée n'est pas une créance, c'est l'épargne du chauffeur.
-- Ces photos restent servies telles quelles (compte de résultat d'un mois
-- clôturé, dotation du mois suivant), d'où leur redressement ici.
--
-- On ne rejoue pas toute la photo : seule la part cotisation en sort, recalculée
-- à la date d'arrêté avec la formule de l'époque (encaissements et annulations
-- datés). Le reste de l'actif figé ne bouge pas.
--
-- La provision se redresse tranche par tranche avec les taux en vigueur ; elle
-- peut différer d'1 FCFA de ce qu'un recalcul complet donnerait, l'arrondi se
-- faisant à l'origine sur la base entière de chaque tranche.
--
-- Seules les clôtures antérieures à l'installation de V1.11.8 sont touchées :
-- celles d'après ont été calculées sans cotisation.

CREATE TEMPORARY TABLE redressement_cloture ON COMMIT DROP AS
WITH taux AS (
    SELECT COALESCE((SELECT valeur::numeric FROM parametres_generaux
                     WHERE cle = 'PROVISION_CREANCES_TAUX_0_7'), 0)     AS t0_7,
           COALESCE((SELECT valeur::numeric FROM parametres_generaux
                     WHERE cle = 'PROVISION_CREANCES_TAUX_8_30'), 25)   AS t8_30,
           COALESCE((SELECT valeur::numeric FROM parametres_generaux
                     WHERE cle = 'PROVISION_CREANCES_TAUX_PLUS_30'), 50) AS tplus_30
),
photos AS (
    SELECT e.id,
           c.annee,
           c.mois,
           (make_date(c.annee, c.mois, 1) + INTERVAL '1 month' - INTERVAL '1 day')::date AS d
    FROM etats_cloture_periode e
    JOIN clotures_periode c ON c.id = e.cloture_periode_id
    WHERE c.date_cloture < (SELECT installed_on FROM flyway_schema_history
                            WHERE version = '1.11.8')
),
cotisations AS (
    SELECT p.id,
           lc.date_cotisation,
           p.d,
           lc.montant_du - COALESCE((
               SELECT SUM(ec.montant) FROM encaissements_cotisation ec
                WHERE ec.ligne_cotisation_id = lc.id
                  AND ec.date_encaissement <= p.d
                  AND (ec.annule_le IS NULL OR ec.annule_le::date > p.d)), 0) AS restant
    FROM photos p
    JOIN lignes_cotisation lc
      ON lc.date_cotisation <= p.d
     AND (lc.annule_le IS NULL OR lc.annule_le::date > p.d)
     AND lc.montant_du IS NOT NULL
    JOIN chauffeurs ch ON ch.id = lc.chauffeur_id
),
tranches AS (
    SELECT p.id, p.annee, p.mois,
           COALESCE(SUM(c.restant) FILTER (WHERE c.date_cotisation > c.d - 8), 0)  AS b0_7,
           COALESCE(SUM(c.restant) FILTER (WHERE c.date_cotisation <= c.d - 8
                                             AND c.date_cotisation > c.d - 31), 0) AS b8_30,
           COALESCE(SUM(c.restant) FILTER (WHERE c.date_cotisation <= c.d - 31), 0) AS bplus_30
    FROM photos p
    LEFT JOIN cotisations c ON c.id = p.id AND c.restant > 0
    GROUP BY p.id, p.annee, p.mois
)
SELECT t.id, t.annee, t.mois,
       t.b0_7 + t.b8_30 + t.bplus_30 AS delta_creances,
       ROUND(t.b0_7 * x.t0_7 / 100)
         + ROUND(t.b8_30 * x.t8_30 / 100)
         + ROUND(t.bplus_30 * x.tplus_30 / 100) AS delta_provision
FROM tranches t CROSS JOIN taux x;

-- La dotation est une variation de stock : celle du mois perd sa propre baisse
-- de provision et regagne celle du mois précédent (s'il a été redressé aussi).
CREATE TEMPORARY TABLE redressement_dotation ON COMMIT DROP AS
SELECT r.id,
       r.delta_provision - COALESCE(prec.delta_provision, 0) AS delta_dotation
FROM redressement_cloture r
LEFT JOIN redressement_cloture prec
       ON make_date(prec.annee, prec.mois, 1) = make_date(r.annee, r.mois, 1) - INTERVAL '1 month';

UPDATE etats_cloture_periode e
SET creances_chauffeurs  = e.creances_chauffeurs - r.delta_creances,
    provision_creances   = e.provision_creances - r.delta_provision,
    creances_nettes      = e.creances_nettes - (r.delta_creances - r.delta_provision),
    total_actif          = e.total_actif - (r.delta_creances - r.delta_provision),
    situation_nette      = e.situation_nette - (r.delta_creances - r.delta_provision),
    dotation_provisions  = CASE WHEN e.dotation_provisions IS NULL THEN NULL
                                ELSE e.dotation_provisions - d.delta_dotation END,
    resultat_caisse      = CASE WHEN e.dotation_provisions IS NULL THEN e.resultat_caisse
                                ELSE e.resultat_caisse + d.delta_dotation END,
    resultat_engagement  = CASE WHEN e.dotation_provisions IS NULL THEN e.resultat_engagement
                                ELSE e.resultat_engagement + d.delta_dotation END,
    updated_at           = now(),
    updated_by           = 'flyway V1.12.0'
FROM redressement_cloture r
JOIN redressement_dotation d ON d.id = r.id
WHERE e.id = r.id
  AND (r.delta_creances <> 0 OR d.delta_dotation <> 0);
