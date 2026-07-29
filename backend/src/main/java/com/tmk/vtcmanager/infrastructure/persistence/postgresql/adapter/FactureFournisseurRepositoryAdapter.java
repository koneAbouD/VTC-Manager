package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;
import com.tmk.vtcmanager.application.ports.persistence.FactureFournisseurRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.FactureFournisseurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.FournisseurPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class FactureFournisseurRepositoryAdapter implements FactureFournisseurRepository {

    private final FactureFournisseurJpaRepository jpaRepository;
    private final FournisseurPersistenceMapper mapper;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public FactureFournisseur save(FactureFournisseur facture) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(facture)));
    }

    @Override
    public Optional<FactureFournisseur> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<FactureFournisseur> findByPeriode(LocalDate debut, LocalDate fin) {
        return mapper.toFactureDomainList(jpaRepository.findByPeriode(debut, fin));
    }

    @Override
    public List<FactureFournisseur> findOuvertes(Long fournisseurId) {
        return mapper.toFactureDomainList(jpaRepository.findOuvertes(fournisseurId));
    }

    /**
     * Dette à une date : les factures émises jusque-là, moins les règlements
     * intervenus jusque-là. Le montant payé stocké sur la facture reflète
     * aujourd'hui ; pour une date passée, seuls les règlements antérieurs
     * comptent — d'où la somme des écritures de règlement plutôt que le champ.
     */
    @Override
    public BigDecimal detteALaDate(LocalDate date) {
        BigDecimal dette = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(f.montant - COALESCE((
                           SELECT SUM(o.montant) FROM operations_financieres o
                           WHERE o.facture_fournisseur_id = f.id
                             AND o.statut IN ('ENCAISSE', 'PAYE')
                             AND o.date_operation <= ?), 0)), 0)
                FROM factures_fournisseur f
                WHERE f.statut <> 'ANNULEE' AND f.date_facture <= ?
                """, BigDecimal.class, date, date);
        return dette != null && dette.signum() > 0 ? dette : BigDecimal.ZERO;
    }

    /**
     * Charges engagées de la période : montant des factures reçues, par nature
     * de résultat. Les factures annulées sont exclues, ainsi que celles dont la
     * catégorie est hors résultat.
     */
    @Override
    public Map<String, BigDecimal> chargesEngageesParNature(LocalDate debut, LocalDate fin) {
        Map<String, BigDecimal> totaux = new HashMap<>();
        jdbcTemplate.query("""
                SELECT c.nature_resultat AS nature, COALESCE(SUM(f.montant), 0) AS total
                FROM factures_fournisseur f
                JOIN categories_operation c ON c.id = f.categorie_id
                WHERE f.statut <> 'ANNULEE'
                  AND f.date_facture BETWEEN ? AND ?
                  AND c.nature_resultat <> 'HORS_RESULTAT'
                GROUP BY c.nature_resultat
                """,
                rs -> { totaux.put(rs.getString("nature"), rs.getBigDecimal("total")); },
                debut, fin);
        return totaux;
    }
}
