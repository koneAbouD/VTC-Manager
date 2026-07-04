package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

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

@Component
@RequiredArgsConstructor
public class FinanceReportingRepositoryAdapter implements FinanceReportingRepository {

    private final JdbcTemplate jdbcTemplate;

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
    public BigDecimal produitsEngagement(LocalDate debut, LocalDate fin) {
        BigDecimal total = jdbcTemplate.queryForObject("""
                SELECT COALESCE((SELECT SUM(lr.montant_attendu) FROM lignes_recette lr
                                 WHERE lr.statut <> 'ANNULEE' AND lr.montant_attendu IS NOT NULL
                                   AND lr.date_recette BETWEEN ? AND ?), 0)
                     + COALESCE((SELECT SUM(lc.montant_du) FROM lignes_cotisation lc
                                 WHERE lc.statut <> 'ANNULEE'
                                   AND lc.date_cotisation BETWEEN ? AND ?), 0)
                     + COALESCE((SELECT SUM(lp.montant) FROM lignes_penalite lp
                                 WHERE lp.statut <> 'ANNULEE' AND lp.type_sanction = 'AMENDE'
                                   AND COALESCE(lp.date_faute, lp.date_generation) BETWEEN ? AND ?), 0)
                """, BigDecimal.class, debut, fin, debut, fin, debut, fin);
        return total == null ? BigDecimal.ZERO : total;
    }

    @Override
    public BigDecimal dotationAmortissements(LocalDate debut, LocalDate fin) {
        // Dotation mensuelle pleine (prix/durée) pour chaque véhicule dont
        // l'amortissement (départ = date d'achat, à défaut entrée flotte /
        // mise en circulation) couvre la période et n'est pas achevé.
        BigDecimal total = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(v.prix_achat / v.duree_amortissement_mois), 0)
                FROM vehicules v
                WHERE v.prix_achat IS NOT NULL
                  AND v.duree_amortissement_mois > 0
                  AND COALESCE(v.date_achat, v.date_entree_flotte, v.date_mise_en_circulation) IS NOT NULL
                  AND COALESCE(v.date_achat, v.date_entree_flotte, v.date_mise_en_circulation) <= ?
                  AND COALESCE(v.date_achat, v.date_entree_flotte, v.date_mise_en_circulation)
                      + (v.duree_amortissement_mois || ' months')::interval > ?
                """, BigDecimal.class, fin, debut);
        return total == null ? BigDecimal.ZERO : total;
    }

    @Override
    public BigDecimal immobilisationsNettes(LocalDate date) {
        // VNC = prix × (1 − mois écoulés / durée), bornée à 0.
        BigDecimal total = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(GREATEST(0,
                           v.prix_achat * (1 - (
                               EXTRACT(YEAR FROM age(?::date, d.depart)) * 12
                             + EXTRACT(MONTH FROM age(?::date, d.depart))
                           ) / v.duree_amortissement_mois))), 0)
                FROM vehicules v
                CROSS JOIN LATERAL (SELECT COALESCE(v.date_achat, v.date_entree_flotte,
                                                    v.date_mise_en_circulation) AS depart) d
                WHERE v.prix_achat IS NOT NULL
                  AND v.duree_amortissement_mois > 0
                  AND d.depart IS NOT NULL
                  AND d.depart <= ?::date
                """, BigDecimal.class, date, date, date);
        return total == null ? BigDecimal.ZERO : total;
    }

    @Override
    public List<MargeVehicule> margesParVehicule(LocalDate debut, LocalDate fin) {
        return jdbcTemplate.query("""
                SELECT v.id, v.immatriculation,
                       COALESCE(SUM(o.montant) FILTER (WHERE c.nature_resultat = 'PRODUIT_EXPLOITATION'), 0) AS produits,
                       COALESCE(SUM(o.montant) FILTER (WHERE c.nature_resultat = 'CHARGE_VARIABLE'), 0)      AS charges
                FROM operations_financieres o
                JOIN categories_operation c ON c.id = o.categorie_id
                JOIN vehicules v            ON v.id = o.vehicule_id
                WHERE o.statut IN ('ENCAISSE', 'PAYE')
                  AND o.date_operation BETWEEN ? AND ?
                  AND c.nature_resultat IN ('PRODUIT_EXPLOITATION', 'CHARGE_VARIABLE')
                GROUP BY v.id, v.immatriculation
                ORDER BY (COALESCE(SUM(o.montant) FILTER (WHERE c.nature_resultat = 'PRODUIT_EXPLOITATION'), 0)
                        - COALESCE(SUM(o.montant) FILTER (WHERE c.nature_resultat = 'CHARGE_VARIABLE'), 0)) DESC
                """,
                (rs, i) -> {
                    BigDecimal produits = rs.getBigDecimal("produits");
                    BigDecimal charges = rs.getBigDecimal("charges");
                    return MargeVehicule.builder()
                            .vehiculeId(rs.getLong("id"))
                            .immatriculation(rs.getString("immatriculation"))
                            .produits(produits)
                            .chargesVariables(charges)
                            .marge(produits.subtract(charges))
                            .build();
                },
                debut, fin);
    }
}
