package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CompteTresorerieEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CompteTresorerieJpaRepository extends JpaRepository<CompteTresorerieEntity, Long> {

    Optional<CompteTresorerieEntity> findByCode(String code);

    boolean existsByCode(String code);

    List<CompteTresorerieEntity> findByActifTrueOrderByLibelle();

    Optional<CompteTresorerieEntity> findByTypeAndParDefautTrue(TypeCompteTresorerie type);

    long countByTypeAndActifTrue(TypeCompteTresorerie type);

    /**
     * Soldes par compte : solde_initial + somme des opérations terminées
     * (REVENU en +, DEPENSE en −) + transferts entrants − transferts
     * sortants. ANNULEE exclu — une annulation est donc neutre sur le solde
     * sans écriture inverse.
     *
     * <p>Bornée à {@code date} — le jour même en pratique : un solde de
     * trésorerie dit ce que le compte détient <em>maintenant</em>. Y compter
     * une écriture postdatée ferait entrer un argent que personne n'a encore
     * reçu, et surtout ferait diverger ce solde de celui que
     * {@link #calculerSoldeALaDate(Long, java.time.LocalDate)} oppose au
     * comptage : l'écran annoncerait un écart nul là où la clôture en voit un.
     */
    @Query(value = """
            SELECT c.id AS compteId,
                   c.solde_initial
                   + COALESCE((SELECT SUM(CASE WHEN o.type_operation = 'REVENU' THEN o.montant
                                               ELSE -o.montant END)
                               FROM operations_financieres o
                               WHERE o.compte_tresorerie_id = c.id
                                 AND o.statut IN ('ENCAISSE', 'PAYE')
                                 AND o.date_operation <= :date), 0)
                   + COALESCE((SELECT SUM(t.montant) FROM transferts_tresorerie t
                               WHERE t.compte_destination_id = c.id
                                 AND t.date_transfert <= :date), 0)
                   - COALESCE((SELECT SUM(t.montant) FROM transferts_tresorerie t
                               WHERE t.compte_source_id = c.id
                                 AND t.date_transfert <= :date), 0) AS solde
            FROM comptes_tresorerie c
            WHERE (:actifsSeulement = FALSE OR c.actif)
            """, nativeQuery = true)
    List<SoldeCompteProjection> calculerSoldes(@Param("actifsSeulement") boolean actifsSeulement,
                                               @Param("date") java.time.LocalDate date);

    /**
     * Solde d'un compte arrêté à une date : même formule que
     * {@link #calculerSoldes(boolean, java.time.LocalDate)}, pour une date
     * quelconque plutôt que pour le jour même.
     */
    @Query(value = """
            SELECT c.solde_initial
                   + COALESCE((SELECT SUM(CASE WHEN o.type_operation = 'REVENU' THEN o.montant
                                               ELSE -o.montant END)
                               FROM operations_financieres o
                               WHERE o.compte_tresorerie_id = c.id
                                 AND o.statut IN ('ENCAISSE', 'PAYE')
                                 AND o.date_operation <= :date), 0)
                   + COALESCE((SELECT SUM(t.montant) FROM transferts_tresorerie t
                               WHERE t.compte_destination_id = c.id
                                 AND t.date_transfert <= :date), 0)
                   - COALESCE((SELECT SUM(t.montant) FROM transferts_tresorerie t
                               WHERE t.compte_source_id = c.id
                                 AND t.date_transfert <= :date), 0)
            FROM comptes_tresorerie c
            WHERE c.id = :compteId
            """, nativeQuery = true)
    java.math.BigDecimal calculerSoldeALaDate(@Param("compteId") Long compteId,
                                              @Param("date") java.time.LocalDate date);

    interface SoldeCompteProjection {
        Long getCompteId();
        java.math.BigDecimal getSolde();
    }
}
