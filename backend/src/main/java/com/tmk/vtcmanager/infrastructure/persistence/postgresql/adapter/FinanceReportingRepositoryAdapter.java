package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.AmortissementVehicule;
import com.tmk.vtcmanager.application.domain.finance.MargeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class FinanceReportingRepositoryAdapter implements FinanceReportingRepository {

    private final JdbcTemplate jdbcTemplate;

    /**
     * Durée d'amortissement effective d'un véhicule (alias {@code v}) : override
     * du véhicule s'il existe, sinon le paramètre global DUREE_AMORTISSEMENT_MOIS,
     * sinon 60 en dernier recours.
     */
    private static final String DUREE_EFFECTIVE =
            "COALESCE(v.duree_amortissement_mois, "
            + "(SELECT NULLIF(p.valeur, '')::int FROM parametres_generaux p "
            + "WHERE p.cle = 'DUREE_AMORTISSEMENT_MOIS'), 60)";

    /**
     * Plan d'amortissement d'un véhicule (alias {@code v}), en deux jointures
     * latérales injectées via {@code replace("{{PLAN}}", …)} :
     * <ul>
     *   <li>{@code a.depart} — premier jour amorti. C'est l'entrée en flotte qui
     *       fait foi : un véhicule d'occasion ne s'amortit pas depuis sa
     *       première immatriculation, mais depuis sa mise en service chez
     *       nous. L'achat et la mise en circulation ne sont que des replis.</li>
     *   <li>{@code p.finExclue} — lendemain du dernier jour amorti.</li>
     * </ul>
     *
     * <p>Le plan est exprimé <b>en jours</b>, pas en mensualités : c'est ce qui
     * permet au mois d'entrée et au mois de sortie d'être servis au prorata, et
     * au cumul des dotations de tomber exactement sur le prix d'achat. Compter
     * deux mois entiers aux deux bouts revenait à servir une mensualité de trop.
     *
     * <p>Dotation et valeur nette comptable dérivent toutes deux de ce plan :
     * deux formules indépendantes finissaient par ne plus désigner le même mois.
     */
    private static final String PLAN_AMORTISSEMENT = """
            CROSS JOIN LATERAL (
                SELECT {{DUREE}} AS duree,
                       COALESCE(v.date_entree_flotte, v.date_achat,
                                v.date_mise_en_circulation) AS depart
            ) a
            CROSS JOIN LATERAL (
                SELECT (a.depart + (a.duree || ' months')::interval)::date AS fin_exclue
            ) p
            """.replace("{{DUREE}}", DUREE_EFFECTIVE);

    /** Un véhicule est amortissable si son plan est exploitable. */
    private static final String PLAN_EXPLOITABLE = """
            v.prix_achat IS NOT NULL
              AND a.duree > 0
              AND a.depart IS NOT NULL
              AND p.fin_exclue > a.depart
            """;

    /**
     * Jours amortis d'une période, bornés au plan. Deux paramètres, dans l'ordre
     * d'apparition : <b>fin</b> de période, puis <b>début</b>.
     */
    private static final String JOURS_AMORTIS_PERIODE =
            "GREATEST(0, LEAST(p.fin_exclue - 1, ?::date) - GREATEST(a.depart, ?::date) + 1)";

    @Override
    public Map<String, BigDecimal> totauxCaisseParNature(LocalDate debut, LocalDate fin) {
        Map<String, BigDecimal> totaux = new HashMap<>();
        jdbcTemplate.query("""
                SELECT c.nature_resultat AS nature, COALESCE(SUM(o.montant), 0) AS total
                FROM operations_financieres o
                JOIN categories_operation c ON c.id = o.categorie_id
                WHERE o.statut IN ('ENCAISSE', 'PAYE')
                  AND o.date_operation BETWEEN ? AND ?
                  AND c.nature_resultat <> 'HORS_RESULTAT'
                GROUP BY c.nature_resultat
                """,
                rs -> { totaux.put(rs.getString("nature"), rs.getBigDecimal("total")); },
                debut, fin);
        return totaux;
    }

    @Override
    public Map<String, BigDecimal> totauxCaisseHorsFactureParNature(LocalDate debut, LocalDate fin) {
        Map<String, BigDecimal> totaux = new HashMap<>();
        jdbcTemplate.query("""
                SELECT c.nature_resultat AS nature, COALESCE(SUM(o.montant), 0) AS total
                FROM operations_financieres o
                JOIN categories_operation c ON c.id = o.categorie_id
                WHERE o.statut IN ('ENCAISSE', 'PAYE')
                  AND o.date_operation BETWEEN ? AND ?
                  AND c.nature_resultat <> 'HORS_RESULTAT'
                  AND o.facture_partenaire_id IS NULL
                GROUP BY c.nature_resultat
                """,
                rs -> { totaux.put(rs.getString("nature"), rs.getBigDecimal("total")); },
                debut, fin);
        return totaux;
    }

    @Override
    public BigDecimal produitsEngagement(LocalDate debut, LocalDate fin) {
        // Les cotisations ne sont PAS un produit (dépôt HORS_RESULTAT, restitué en
        // fin de période) : elles sont exclues du produit d'exploitation engagement.
        BigDecimal total = jdbcTemplate.queryForObject("""
                SELECT COALESCE((SELECT SUM(lr.montant_attendu) FROM lignes_recette lr
                                 WHERE lr.statut <> 'ANNULEE' AND lr.montant_attendu IS NOT NULL
                                   AND lr.date_recette BETWEEN ? AND ?), 0)
                     + COALESCE((SELECT SUM(lp.montant) FROM lignes_penalite lp
                                 WHERE lp.statut <> 'ANNULEE' AND lp.type_sanction = 'AMENDE'
                                   AND COALESCE(lp.date_faute, lp.date_generation) BETWEEN ? AND ?), 0)
                """, BigDecimal.class, debut, fin, debut, fin);
        return total == null ? BigDecimal.ZERO : total;
    }

    @Override
    public BigDecimal dotationAmortissements(LocalDate debut, LocalDate fin) {
        // Quote-part de la période dans le plan : jours amortis du mois rapportés
        // aux jours du plan entier. Le mois d'entrée et le mois de sortie sont
        // donc partiels, et la somme sur toute la vie du bien vaut son prix.
        BigDecimal total = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(
                           v.prix_achat * {{JOURS}}::numeric / (p.fin_exclue - a.depart)
                       ), 0)
                FROM vehicules v
                {{PLAN}}
                WHERE {{EXPLOITABLE}}
                  AND a.depart <= ?::date
                  AND p.fin_exclue > ?::date
                """
                .replace("{{JOURS}}", JOURS_AMORTIS_PERIODE)
                .replace("{{PLAN}}", PLAN_AMORTISSEMENT)
                .replace("{{EXPLOITABLE}}", PLAN_EXPLOITABLE),
                // Jours amortis : fin, debut ; puis bornes du plan : fin, debut.
                BigDecimal.class, fin, debut, fin, debut);
        return total == null ? BigDecimal.ZERO : total;
    }

    @Override
    public BigDecimal immobilisationsNettes(LocalDate date) {
        // VNC = prix − cumul des dotations depuis le départ, au même plan que
        // le compte de résultat : l'actif ne peut plus porter un véhicule que
        // le résultat a fini de passer en charge.
        BigDecimal total = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(GREATEST(0,
                           v.prix_achat - v.prix_achat
                               * GREATEST(0, LEAST(p.fin_exclue - 1, ?::date) - a.depart + 1)::numeric
                               / (p.fin_exclue - a.depart))), 0)
                FROM vehicules v
                {{PLAN}}
                WHERE {{EXPLOITABLE}}
                  AND a.depart <= ?::date
                """
                .replace("{{PLAN}}", PLAN_AMORTISSEMENT)
                .replace("{{EXPLOITABLE}}", PLAN_EXPLOITABLE),
                BigDecimal.class, date, date);
        return total == null ? BigDecimal.ZERO : total;
    }

    @Override
    public Optional<AmortissementVehicule> amortissementVehicule(Long vehiculeId, LocalDate date) {
        // Même plan, même borne et même formule que immobilisationsNettes : la
        // fiche véhicule sert la part de l'actif qui lui revient, pas une
        // estimation parallèle. La VNC reste nulle quand le plan n'est pas
        // exploitable ou n'a pas commencé — le bilan ne porte pas ce véhicule
        // non plus.
        List<AmortissementVehicule> resultats = jdbcTemplate.query("""
                SELECT a.duree AS duree,
                       a.depart AS depart,
                       CASE WHEN {{EXPLOITABLE}} AND a.depart <= ?::date
                            THEN GREATEST(0, v.prix_achat - v.prix_achat
                                     * GREATEST(0, LEAST(p.fin_exclue - 1, ?::date) - a.depart + 1)::numeric
                                     / (p.fin_exclue - a.depart))
                       END AS vnc
                FROM vehicules v
                {{PLAN}}
                WHERE v.id = ?
                """
                .replace("{{PLAN}}", PLAN_AMORTISSEMENT)
                .replace("{{EXPLOITABLE}}", PLAN_EXPLOITABLE),
                (rs, i) -> {
                    java.sql.Date depart = rs.getDate("depart");
                    return new AmortissementVehicule(
                            vehiculeId,
                            rs.getInt("duree"),
                            depart == null ? null : depart.toLocalDate(),
                            rs.getBigDecimal("vnc"));
                },
                date, date, vehiculeId);
        return resultats.stream().findFirst();
    }

    @Override
    public List<MargeVehicule> margesParVehicule(LocalDate debut, LocalDate fin) {
        // Piloté PAR véhicule (LEFT JOIN opérations) pour que les véhicules
        // immobilisés SANS aucune opération sur la période apparaissent quand même :
        // on garde une ligne dès qu'il y a une opération produit/charge OU des jours
        // d'immobilisation. Les véhicules sans activité ni immobilisation sont exclus.
        return jdbcTemplate.query("""
                SELECT t.id, t.immatriculation, t.produits, t.charges, t.jours_immo, t.dotation
                FROM (
                    SELECT v.id AS id, v.immatriculation AS immatriculation,
                           COALESCE(SUM(o.montant) FILTER (WHERE c.nature_resultat = 'PRODUIT_EXPLOITATION'), 0) AS produits,
                           COALESCE(SUM(o.montant) FILTER (WHERE c.nature_resultat = 'CHARGE_VARIABLE'), 0)      AS charges,
                           COUNT(o.id) FILTER (WHERE c.nature_resultat IS NOT NULL)                              AS nb_ops,
                           COALESCE((
                               SELECT SUM(GREATEST(0,
                                          (LEAST(COALESCE(iv.date_fin, ?), ?) - GREATEST(iv.date_debut, ?)) + 1))
                               FROM indisponibilites_vehicule iv
                               WHERE iv.vehicule_id = v.id
                                 AND iv.statut <> 'ANNULEE'
                                 AND iv.date_debut <= ?
                                 AND (iv.date_fin IS NULL OR iv.date_fin >= ?)
                           ), 0) AS jours_immo,
                           dot.montant AS dotation
                    FROM vehicules v
                    {{PLAN}}
                    -- Même plan que le compte de résultat : la somme des marges
                    -- nettes par véhicule doit rester la dotation globale du mois.
                    CROSS JOIN LATERAL (
                        SELECT CASE WHEN {{EXPLOITABLE}}
                                     AND a.depart <= ?::date
                                     AND p.fin_exclue > ?::date
                                    THEN v.prix_achat * {{JOURS}}::numeric
                                         / (p.fin_exclue - a.depart)
                                    ELSE 0 END AS montant
                    ) dot
                    LEFT JOIN operations_financieres o
                           ON o.vehicule_id = v.id
                          AND o.statut IN ('ENCAISSE', 'PAYE')
                          AND o.date_operation BETWEEN ? AND ?
                    LEFT JOIN categories_operation c
                           ON c.id = o.categorie_id
                          AND c.nature_resultat IN ('PRODUIT_EXPLOITATION', 'CHARGE_VARIABLE')
                    GROUP BY v.id, v.immatriculation, dot.montant
                ) t
                WHERE t.nb_ops > 0 OR t.jours_immo > 0
                ORDER BY (t.produits - t.charges - t.dotation) DESC
                """
                .replace("{{JOURS}}", JOURS_AMORTIS_PERIODE)
                .replace("{{PLAN}}", PLAN_AMORTISSEMENT)
                .replace("{{EXPLOITABLE}}", PLAN_EXPLOITABLE),
                (rs, i) -> {
                    BigDecimal produits = rs.getBigDecimal("produits");
                    BigDecimal charges = rs.getBigDecimal("charges");
                    BigDecimal dotation = rs.getBigDecimal("dotation");
                    BigDecimal marge = produits.subtract(charges);
                    return MargeVehicule.builder()
                            .vehiculeId(rs.getLong("id"))
                            .immatriculation(rs.getString("immatriculation"))
                            .joursImmobilisation(rs.getLong("jours_immo"))
                            .produits(produits)
                            .chargesVariables(charges)
                            .marge(marge)
                            .dotationAmortissement(dotation)
                            .margeNette(marge.subtract(dotation))
                            .build();
                },
                // Sous-requête jours_immo : fin (LEAST/COALESCE), fin (LEAST), debut (GREATEST),
                // fin (date_debut <=), debut (date_fin >=) ; dotation : fin (départ <=), debut
                // (plan non achevé), puis jours amortis fin, debut ; JOIN opérations : debut, fin.
                fin, fin, debut, fin, debut,
                fin, debut, fin, debut,
                debut, fin);
    }
}
