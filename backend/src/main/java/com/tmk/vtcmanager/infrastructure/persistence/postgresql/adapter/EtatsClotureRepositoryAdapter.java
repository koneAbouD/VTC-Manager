package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * Archive des états de clôture, en SQL direct : ce sont des lignes écrites une
 * fois et relues telles quelles — pas de cycle de vie JPA à gérer.
 */
@Repository
@RequiredArgsConstructor
public class EtatsClotureRepositoryAdapter implements EtatsClotureRepository {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public EtatsCloture save(EtatsCloture e) {
        Long id = jdbcTemplate.queryForObject("""
                INSERT INTO etats_cloture_periode (
                    cloture_periode_id, produits_caisse, charges_variables, charges_fixes,
                    amortissements, resultat_caisse, produits_engagement, resultat_engagement,
                    pont_creances, tresorerie, creances_chauffeurs, immobilisations_nettes,
                    total_actif, dette_etat, situation_nette, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                RETURNING id
                """, Long.class,
                e.getCloturePeriodeId(), e.getProduitsCaisse(), e.getChargesVariables(),
                e.getChargesFixes(), e.getAmortissements(), e.getResultatCaisse(),
                e.getProduitsEngagement(), e.getResultatEngagement(), e.getPontCreances(),
                e.getTresorerie(), e.getCreancesChauffeurs(), e.getImmobilisationsNettes(),
                e.getTotalActif(), e.getDetteEtat(), e.getSituationNette());
        e.setId(id);

        if (e.getSoldes() != null) {
            for (EtatsCloture.SoldeCompteCloture s : e.getSoldes()) {
                jdbcTemplate.update("""
                        INSERT INTO soldes_cloture_periode
                            (cloture_periode_id, compte_id, libelle_compte, solde)
                        VALUES (?, ?, ?, ?)
                        ON CONFLICT (cloture_periode_id, compte_id) DO NOTHING
                        """, e.getCloturePeriodeId(), s.getCompteId(), s.getLibelleCompte(), s.getSolde());
            }
        }
        return e;
    }

    @Override
    public Optional<EtatsCloture> findByPeriode(int annee, int mois) {
        List<EtatsCloture> resultats = jdbcTemplate.query("""
                SELECT e.*, c.annee, c.mois
                FROM etats_cloture_periode e
                JOIN clotures_periode c ON c.id = e.cloture_periode_id
                WHERE c.annee = ? AND c.mois = ?
                """, (rs, i) -> EtatsCloture.builder()
                        .id(rs.getLong("id"))
                        .cloturePeriodeId(rs.getLong("cloture_periode_id"))
                        .annee(rs.getInt("annee"))
                        .mois(rs.getInt("mois"))
                        .produitsCaisse(rs.getBigDecimal("produits_caisse"))
                        .chargesVariables(rs.getBigDecimal("charges_variables"))
                        .chargesFixes(rs.getBigDecimal("charges_fixes"))
                        .amortissements(rs.getBigDecimal("amortissements"))
                        .resultatCaisse(rs.getBigDecimal("resultat_caisse"))
                        .produitsEngagement(rs.getBigDecimal("produits_engagement"))
                        .resultatEngagement(rs.getBigDecimal("resultat_engagement"))
                        .pontCreances(rs.getBigDecimal("pont_creances"))
                        .tresorerie(rs.getBigDecimal("tresorerie"))
                        .creancesChauffeurs(rs.getBigDecimal("creances_chauffeurs"))
                        .immobilisationsNettes(rs.getBigDecimal("immobilisations_nettes"))
                        .totalActif(rs.getBigDecimal("total_actif"))
                        .detteEtat(rs.getBigDecimal("dette_etat"))
                        .situationNette(rs.getBigDecimal("situation_nette"))
                        .build(),
                annee, mois);

        if (resultats.isEmpty()) return Optional.empty();
        EtatsCloture etats = resultats.get(0);
        etats.setSoldes(jdbcTemplate.query("""
                SELECT compte_id, libelle_compte, solde
                FROM soldes_cloture_periode
                WHERE cloture_periode_id = ?
                ORDER BY libelle_compte
                """, (rs, i) -> EtatsCloture.SoldeCompteCloture.builder()
                        .compteId(rs.getLong("compte_id"))
                        .libelleCompte(rs.getString("libelle_compte"))
                        .solde(rs.getBigDecimal("solde"))
                        .build(),
                etats.getCloturePeriodeId()));
        return Optional.of(etats);
    }
}
