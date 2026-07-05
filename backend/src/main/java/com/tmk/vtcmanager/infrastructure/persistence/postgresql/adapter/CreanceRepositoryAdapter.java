package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.CreanceVehicule;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;

@Component
@RequiredArgsConstructor
public class CreanceRepositoryAdapter implements CreanceRepository {

    private final JdbcTemplate jdbcTemplate;

    /** Mapper commun aux détails (par chauffeur et par véhicule). */
    private static final RowMapper<LigneCreance> LIGNE_MAPPER = (rs, i) -> LigneCreance.builder()
            .document(TypeDocumentCreance.valueOf(rs.getString("document")))
            .documentId(rs.getLong("document_id"))
            .vehiculeId(rs.getObject("vehicule_id", Long.class))
            .chauffeurId(rs.getObject("chauffeur_id", Long.class))
            .chauffeurNom(rs.getString("chauffeur_nom"))
            .dateReference(rs.getDate("date_reference").toLocalDate())
            .montantDu(rs.getBigDecimal("montant_du"))
            .montantRegle(rs.getBigDecimal("montant_regle"))
            .restant(rs.getBigDecimal("restant"))
            .build();

    @Override
    public List<CreanceChauffeur> getBalanceAgee() {
        return jdbcTemplate.query("""
                SELECT v.tiers_id AS chauffeur_id,
                       ch.nom, ch.prenom,
                       COUNT(*) AS nb_lignes,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 8
                                                         AND v.date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30,
                       SUM(v.restant) AS total
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                GROUP BY v.tiers_id, ch.nom, ch.prenom
                ORDER BY total DESC
                """,
                (rs, i) -> CreanceChauffeur.builder()
                        .chauffeurId(rs.getLong("chauffeur_id"))
                        .chauffeurNom(rs.getString("nom"))
                        .chauffeurPrenom(rs.getString("prenom"))
                        .nbLignes(rs.getInt("nb_lignes"))
                        .du0a7Jours(rs.getBigDecimal("du_0_7"))
                        .du8a30Jours(rs.getBigDecimal("du_8_30"))
                        .duPlus30Jours(rs.getBigDecimal("du_plus_30"))
                        .total(rs.getBigDecimal("total"))
                        .build());
    }

    @Override
    public List<LigneCreance> getLignesCreance(Long chauffeurId) {
        return jdbcTemplate.query("""
                SELECT v.document, v.document_id, v.vehicule_id,
                       v.tiers_id AS chauffeur_id,
                       TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom,
                       v.date_reference, v.montant_du, v.montant_regle, v.restant
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.tiers_id = ?
                ORDER BY v.date_reference
                """, LIGNE_MAPPER, chauffeurId);
    }

    @Override
    public List<CreanceVehicule> getBalanceAgeeParVehicule() {
        return jdbcTemplate.query("""
                SELECT v.vehicule_id,
                       veh.immatriculation, mar.nom AS marque, mod.nom AS modele,
                       COUNT(*) AS nb_lignes,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 8
                                                         AND v.date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30,
                       SUM(v.restant) AS total
                FROM v_creances_chauffeurs v
                JOIN vehicules veh ON veh.id = v.vehicule_id
                LEFT JOIN marques mar ON mar.id = veh.marque_id
                LEFT JOIN modeles mod ON mod.id = veh.modele_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.vehicule_id IS NOT NULL
                GROUP BY v.vehicule_id, veh.immatriculation, mar.nom, mod.nom
                ORDER BY total DESC
                """,
                (rs, i) -> CreanceVehicule.builder()
                        .vehiculeId(rs.getLong("vehicule_id"))
                        .immatriculation(rs.getString("immatriculation"))
                        .marque(rs.getString("marque"))
                        .modele(rs.getString("modele"))
                        .nbLignes(rs.getInt("nb_lignes"))
                        .du0a7Jours(rs.getBigDecimal("du_0_7"))
                        .du8a30Jours(rs.getBigDecimal("du_8_30"))
                        .duPlus30Jours(rs.getBigDecimal("du_plus_30"))
                        .total(rs.getBigDecimal("total"))
                        .build());
    }

    @Override
    public List<LigneCreance> getLignesCreanceParVehicule(Long vehiculeId) {
        return jdbcTemplate.query("""
                SELECT v.document, v.document_id, v.vehicule_id,
                       v.tiers_id AS chauffeur_id,
                       TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom,
                       v.date_reference, v.montant_du, v.montant_regle, v.restant
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.vehicule_id = ?
                ORDER BY v.date_reference
                """, LIGNE_MAPPER, vehiculeId);
    }

    @Override
    public BigDecimal getMontantAReverserEtat() {
        BigDecimal montant = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(COALESCE(montant_paye, 0)), 0)
                FROM contraventions
                WHERE statut IN ('EN_ATTENTE', 'PARTIELLEMENT_PAYE', 'PAYE')
                """, BigDecimal.class);
        return montant == null ? BigDecimal.ZERO : montant;
    }
}
