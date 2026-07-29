package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FactureFournisseurEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface FactureFournisseurJpaRepository extends JpaRepository<FactureFournisseurEntity, Long> {

    @Query("""
            SELECT f FROM FactureFournisseurEntity f
            WHERE f.dateFacture >= :debut AND f.dateFacture <= :fin
            ORDER BY f.dateFacture DESC, f.id DESC
            """)
    List<FactureFournisseurEntity> findByPeriode(@Param("debut") LocalDate debut,
                                                 @Param("fin") LocalDate fin);

    @Query("""
            SELECT f FROM FactureFournisseurEntity f
            WHERE f.statut IN ('A_PAYER', 'PARTIELLEMENT_PAYEE')
              AND (:fournisseurId IS NULL OR f.fournisseur.id = :fournisseurId)
            ORDER BY f.dateEcheance ASC, f.id ASC
            """)
    List<FactureFournisseurEntity> findOuvertes(@Param("fournisseurId") Long fournisseurId);
}
