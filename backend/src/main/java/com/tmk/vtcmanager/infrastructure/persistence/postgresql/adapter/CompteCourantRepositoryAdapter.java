package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.spec.RechercheVehiculeChauffeur;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Soldes de compte courant : le fonds de cotisation restituable (Σ montant_encaisse
 * non encore restitué) face aux créances ouvertes hors cotisations (recettes,
 * pénalités, contraventions), ventilées par antériorité.
 *
 * <p>La compensation est <b>toujours calculée à la maille chauffeur</b>, y compris
 * sur l'axe véhicule : c'est ce que fait l'arrêté, et un simple « fonds − créances »
 * par véhicule netterait le dépôt d'un chauffeur contre la dette d'un autre. Les
 * deux faces du solde sont donc rendues séparément — le restituable ({@code net})
 * et le reste dû ({@code reste_du}).
 *
 * <p>Seule exception, les dettes du véhicule lui-même (contraventions sans
 * chauffeur) : n'appartenant à personne, elles s'imputent sur l'excédent cumulé
 * des chauffeurs du véhicule.
 */
@Component
@RequiredArgsConstructor
public class CompteCourantRepositoryAdapter implements CompteCourantRepository {

    private static final String STATUTS_FONDS = "'EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE', 'ENCAISSE'";

    /** Part du fonds encore détenue : ce qui a été encaissé moins ce qu'un arrêté a déjà rendu. */
    private static final String FOND_DETENU = "montant_encaisse - montant_restitue";

    private final JdbcTemplate jdbcTemplate;

    private static final RowMapper<CompteCourant> MAPPER = (rs, i) -> CompteCourant.builder()
            .tiersId(rs.getLong("tiers_id"))
            .libelle(rs.getString("libelle"))
            .fondsCotisation(rs.getBigDecimal("fond"))
            .du0a7Jours(rs.getBigDecimal("du_0_7"))
            .du8a30Jours(rs.getBigDecimal("du_8_30"))
            .duPlus30Jours(rs.getBigDecimal("du_plus_30"))
            .totalCreances(rs.getBigDecimal("total_creances"))
            .net(rs.getBigDecimal("net"))
            .resteDu(rs.getBigDecimal("reste_du"))
            .build();

    /** Le nom du chauffeur d'alias {@code ch}, dans les deux ordres. */
    private static final String NOM_CHAUFFEUR_REPOND = """
            (LOWER(ch.nom) LIKE ? OR LOWER(ch.prenom) LIKE ?
             OR LOWER(CONCAT(ch.prenom, ' ', ch.nom)) LIKE ?
             OR LOWER(CONCAT(ch.nom, ' ', ch.prenom)) LIKE ?)""";

    /** L'immatriculation du véhicule d'alias {@code veh}, avec ou sans tirets ni espaces. */
    private static final String IMMAT_REPOND = """
            (LOWER(veh.immatriculation) LIKE ?
             OR REPLACE(REPLACE(LOWER(veh.immatriculation), '-', ''), ' ', '') LIKE ?)""";

    /**
     * Filtre de la liste des tiers, jamais de leurs lignes : le solde affiché
     * reste celui que l'arrêté compenserait. Un tiers répond par son propre
     * nom, ou par celui de l'autre axe dès qu'ils sont liés par une cotisation
     * ou une créance — chercher une immatriculation ramène ses chauffeurs,
     * chercher un chauffeur ramène ses véhicules.
     */
    private record Recherche(String sql, List<Object> params) {

        static final Recherche AUCUNE = new Recherche("", List.of());

        static Recherche parChauffeur(String recherche) {
            if (!RechercheVehiculeChauffeur.estRenseignee(recherche)) return AUCUNE;
            String sql = """
                     AND (%s
                          OR EXISTS (SELECT 1 FROM vehicules veh
                                     WHERE %s
                                       AND veh.id IN (SELECT vehicule_id FROM lignes_cotisation
                                                      WHERE chauffeur_id = ch.id
                                                      UNION
                                                      SELECT vehicule_id FROM v_creances_chauffeurs
                                                      WHERE tiers_type = 'CHAUFFEUR'
                                                        AND tiers_id = ch.id)))"""
                    .formatted(NOM_CHAUFFEUR_REPOND, IMMAT_REPOND);
            List<Object> params = new ArrayList<>(nom(recherche));
            params.addAll(immat(recherche));
            return new Recherche(sql, params);
        }

        static Recherche parVehicule(String recherche) {
            if (!RechercheVehiculeChauffeur.estRenseignee(recherche)) return AUCUNE;
            String sql = """
                     AND (%s
                          OR EXISTS (SELECT 1 FROM chauffeurs ch
                                     WHERE %s
                                       AND ch.id IN (SELECT chauffeur_id FROM lignes_cotisation
                                                     WHERE vehicule_id = veh.id
                                                     UNION
                                                     SELECT tiers_id FROM v_creances_chauffeurs
                                                     WHERE tiers_type = 'CHAUFFEUR'
                                                       AND vehicule_id = veh.id)))"""
                    .formatted(IMMAT_REPOND, NOM_CHAUFFEUR_REPOND);
            List<Object> params = new ArrayList<>(immat(recherche));
            params.addAll(nom(recherche));
            return new Recherche(sql, params);
        }

        private static List<Object> nom(String recherche) {
            String motif = RechercheVehiculeChauffeur.motif(recherche);
            return List.of(motif, motif, motif, motif);
        }

        private static List<Object> immat(String recherche) {
            String motif = RechercheVehiculeChauffeur.motif(recherche);
            return List.of(motif, motif.replace("-", "").replace(" ", ""));
        }
    }

    @Override
    public List<CompteCourant> getComptesCourantsParChauffeur(String recherche) {
        Recherche filtre = Recherche.parChauffeur(recherche);
        return jdbcTemplate.query("""
                WITH fonds AS (
                    SELECT chauffeur_id, SUM(%s) AS fond
                    FROM lignes_cotisation
                    WHERE statut IN (%s)
                    GROUP BY chauffeur_id
                ),
                creances AS (
                    SELECT tiers_id AS chauffeur_id,
                           SUM(restant) AS total,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 8
                                                             AND date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30
                    FROM v_creances_chauffeurs
                    WHERE tiers_type = 'CHAUFFEUR' AND sens = 'ILS_ME_DOIVENT' AND document <> 'COTISATION'
                    GROUP BY tiers_id
                )
                SELECT ch.id AS tiers_id,
                       TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS libelle,
                       COALESCE(f.fond, 0)       AS fond,
                       COALESCE(c.du_0_7, 0)     AS du_0_7,
                       COALESCE(c.du_8_30, 0)    AS du_8_30,
                       COALESCE(c.du_plus_30, 0) AS du_plus_30,
                       COALESCE(c.total, 0)      AS total_creances,
                       GREATEST(COALESCE(f.fond, 0) - COALESCE(c.total, 0), 0) AS net,
                       GREATEST(COALESCE(c.total, 0) - COALESCE(f.fond, 0), 0) AS reste_du
                FROM chauffeurs ch
                LEFT JOIN fonds f    ON f.chauffeur_id = ch.id
                LEFT JOIN creances c ON c.chauffeur_id = ch.id
                WHERE (COALESCE(f.fond, 0) > 0 OR COALESCE(c.total, 0) > 0)%s
                ORDER BY net DESC, reste_du DESC
                """.formatted(FOND_DETENU, STATUTS_FONDS, filtre.sql()), MAPPER,
                filtre.params().toArray());
    }

    @Override
    public List<CompteCourant> getComptesCourantsParVehicule(String recherche) {
        Recherche filtre = Recherche.parVehicule(recherche);
        return jdbcTemplate.query("""
                WITH fonds AS (
                    SELECT vehicule_id, chauffeur_id, SUM(%s) AS fond
                    FROM lignes_cotisation
                    WHERE statut IN (%s)
                    GROUP BY vehicule_id, chauffeur_id
                ),
                creances AS (
                    SELECT vehicule_id, tiers_id AS chauffeur_id,
                           SUM(restant) AS total,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 8
                                                             AND date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30
                    FROM v_creances_chauffeurs
                    WHERE tiers_type = 'CHAUFFEUR' AND sens = 'ILS_ME_DOIVENT'
                      AND document <> 'COTISATION' AND vehicule_id IS NOT NULL
                    GROUP BY vehicule_id, tiers_id
                ),
                -- Dettes du véhicule lui-même (contraventions sans chauffeur) :
                -- personne ne les porte, le fonds commun les paie.
                dettes_vehicule AS (
                    SELECT vehicule_id,
                           SUM(restant) AS total,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 8
                                                             AND date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30
                    FROM v_creances_chauffeurs
                    WHERE tiers_type = 'VEHICULE' AND sens = 'ILS_ME_DOIVENT'
                      AND vehicule_id IS NOT NULL
                    GROUP BY vehicule_id
                ),
                -- Une ligne par (véhicule, chauffeur) : la maille à laquelle la
                -- compensation a le droit de se faire.
                paires AS (
                    SELECT COALESCE(f.vehicule_id, c.vehicule_id) AS vehicule_id,
                           COALESCE(f.fond, 0)       AS fond,
                           COALESCE(c.total, 0)      AS creances,
                           COALESCE(c.du_0_7, 0)     AS du_0_7,
                           COALESCE(c.du_8_30, 0)    AS du_8_30,
                           COALESCE(c.du_plus_30, 0) AS du_plus_30
                    FROM fonds f
                    FULL OUTER JOIN creances c
                      ON c.vehicule_id = f.vehicule_id AND c.chauffeur_id = f.chauffeur_id
                ),
                par_chauffeur AS (
                    SELECT vehicule_id,
                           SUM(fond)       AS fond,
                           SUM(creances)   AS total_creances,
                           SUM(du_0_7)     AS du_0_7,
                           SUM(du_8_30)    AS du_8_30,
                           SUM(du_plus_30) AS du_plus_30,
                           SUM(GREATEST(fond - creances, 0)) AS excedent,
                           SUM(GREATEST(creances - fond, 0)) AS deficit
                    FROM paires
                    GROUP BY vehicule_id
                ),
                -- La dette du véhicule s'impute sur l'excédent des chauffeurs,
                -- une fois leurs propres dettes éteintes : ce que fait l'arrêté
                -- par véhicule.
                soldes AS (
                    SELECT COALESCE(p.vehicule_id, d.vehicule_id) AS vehicule_id,
                           COALESCE(p.fond, 0) AS fond,
                           COALESCE(p.total_creances, 0) + COALESCE(d.total, 0)    AS total_creances,
                           COALESCE(p.du_0_7, 0)     + COALESCE(d.du_0_7, 0)     AS du_0_7,
                           COALESCE(p.du_8_30, 0)    + COALESCE(d.du_8_30, 0)    AS du_8_30,
                           COALESCE(p.du_plus_30, 0) + COALESCE(d.du_plus_30, 0) AS du_plus_30,
                           GREATEST(COALESCE(p.excedent, 0) - COALESCE(d.total, 0), 0) AS net,
                           COALESCE(p.deficit, 0)
                               + GREATEST(COALESCE(d.total, 0) - COALESCE(p.excedent, 0), 0) AS reste_du
                    FROM par_chauffeur p
                    FULL OUTER JOIN dettes_vehicule d ON d.vehicule_id = p.vehicule_id
                )
                SELECT veh.id AS tiers_id,
                       veh.immatriculation AS libelle,
                       s.fond, s.du_0_7, s.du_8_30, s.du_plus_30,
                       s.total_creances, s.net, s.reste_du
                FROM soldes s
                JOIN vehicules veh ON veh.id = s.vehicule_id
                WHERE (s.fond > 0 OR s.total_creances > 0)%s
                ORDER BY s.net DESC, s.reste_du DESC
                """.formatted(FOND_DETENU, STATUTS_FONDS, filtre.sql()), MAPPER,
                filtre.params().toArray());
    }

    /**
     * Dépôts encore détenus à la date : la somme des cotisations encaissées
     * jusque-là, moins celles qu'un arrêté avait déjà rendues.
     *
     * <p>Le statut courant de la ligne ne suffit pas à répondre pour une date
     * passée : une cotisation restituée en mars était bien détenue au 31
     * janvier. On rejoue donc les deux dates — celle de l'encaissement et celle
     * de l'arrêté — comme le fait la dette fournisseurs. Les restitutions se
     * lisent sur les lignes d'arrêté et non sur {@code arrete_id} : une ligne
     * partiellement restituée en garde le fonds résiduel, et cet identifiant
     * unique ne dirait rien du montant rendu.
     *
     * <p>Le statut de la ligne n'est volontairement <b>pas</b> filtré : une
     * cotisation partielle peut être annulée après qu'un arrêté a rendu son
     * versé (abandon du reste impayé). Écarter son encaissement tout en gardant
     * sa restitution ferait baisser le dépôt à tort. Un versement extourné sort
     * déjà par sa propre date d'annulation.
     */
    @Override
    public BigDecimal fondsCotisationsALaDate(LocalDate date) {
        BigDecimal encaisse = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(ec.montant), 0)
                FROM encaissements_cotisation ec
                WHERE ec.annule_le IS NULL
                  AND ec.date_encaissement <= ?
                """, BigDecimal.class, date);
        BigDecimal restitue = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(la.montant), 0)
                FROM lignes_arrete la
                JOIN arretes_compte a ON a.id = la.arrete_id
                WHERE la.sens = 'CREDIT'
                  AND la.document_type = 'COTISATION'
                  AND a.statut <> 'ANNULE'
                  AND a.date_arrete <= ?
                """, BigDecimal.class, date);
        return (encaisse == null ? BigDecimal.ZERO : encaisse)
                .subtract(restitue == null ? BigDecimal.ZERO : restitue);
    }
}
