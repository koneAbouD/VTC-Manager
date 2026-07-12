package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Soldes de compte courant : le fonds de cotisation restituable (Σ montant_encaisse
 * des cotisations actives) face aux créances ouvertes hors cotisations (recettes,
 * pénalités, contraventions), ventilées par antériorité. net = fonds − créances.
 */
@Component
@RequiredArgsConstructor
public class CompteCourantRepositoryAdapter implements CompteCourantRepository {

    private static final String STATUTS_FONDS = "'EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE', 'ENCAISSE'";

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
            .build();

    @Override
    public List<CompteCourant> getComptesCourantsParChauffeur() {
        return jdbcTemplate.query("""
                WITH fonds AS (
                    SELECT chauffeur_id, SUM(montant_encaisse) AS fond
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
                       COALESCE(f.fond, 0) - COALESCE(c.total, 0) AS net
                FROM chauffeurs ch
                LEFT JOIN fonds f    ON f.chauffeur_id = ch.id
                LEFT JOIN creances c ON c.chauffeur_id = ch.id
                WHERE COALESCE(f.fond, 0) > 0 OR COALESCE(c.total, 0) > 0
                ORDER BY net DESC
                """.formatted(STATUTS_FONDS), MAPPER);
    }

    @Override
    public List<CompteCourant> getComptesCourantsParVehicule() {
        return jdbcTemplate.query("""
                WITH fonds AS (
                    SELECT vehicule_id, SUM(montant_encaisse) AS fond
                    FROM lignes_cotisation
                    WHERE statut IN (%s)
                    GROUP BY vehicule_id
                ),
                creances AS (
                    SELECT vehicule_id,
                           SUM(restant) AS total,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 8
                                                             AND date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                           COALESCE(SUM(restant) FILTER (WHERE date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30
                    FROM v_creances_chauffeurs
                    WHERE tiers_type = 'CHAUFFEUR' AND sens = 'ILS_ME_DOIVENT'
                      AND document <> 'COTISATION' AND vehicule_id IS NOT NULL
                    GROUP BY vehicule_id
                )
                SELECT veh.id AS tiers_id,
                       veh.immatriculation AS libelle,
                       COALESCE(f.fond, 0)       AS fond,
                       COALESCE(c.du_0_7, 0)     AS du_0_7,
                       COALESCE(c.du_8_30, 0)    AS du_8_30,
                       COALESCE(c.du_plus_30, 0) AS du_plus_30,
                       COALESCE(c.total, 0)      AS total_creances,
                       COALESCE(f.fond, 0) - COALESCE(c.total, 0) AS net
                FROM vehicules veh
                LEFT JOIN fonds f    ON f.vehicule_id = veh.id
                LEFT JOIN creances c ON c.vehicule_id = veh.id
                WHERE COALESCE(f.fond, 0) > 0 OR COALESCE(c.total, 0) > 0
                ORDER BY net DESC
                """.formatted(STATUTS_FONDS), MAPPER);
    }
}
