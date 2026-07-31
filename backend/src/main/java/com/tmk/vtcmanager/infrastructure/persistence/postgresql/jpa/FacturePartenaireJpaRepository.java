package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FacturePartenaireEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface FacturePartenaireJpaRepository extends JpaRepository<FacturePartenaireEntity, Long> {

    @Query("""
            SELECT f FROM FacturePartenaireEntity f
            WHERE f.dateFacture >= :debut AND f.dateFacture <= :fin
            ORDER BY f.dateFacture DESC, f.id DESC
            """)
    List<FacturePartenaireEntity> findByPeriode(@Param("debut") LocalDate debut,
                                                 @Param("fin") LocalDate fin);

    @Query("""
            SELECT f FROM FacturePartenaireEntity f
            WHERE f.statut IN ('A_PAYER', 'PARTIELLEMENT_PAYEE')
              AND (:partenaireId IS NULL OR f.partenaire.id = :partenaireId)
            ORDER BY f.dateEcheance ASC, f.id ASC
            """)
    List<FacturePartenaireEntity> findOuvertes(@Param("partenaireId") Long partenaireId);

    List<FacturePartenaireEntity> findByMaintenanceIdOrderByIdAsc(Long maintenanceId);
}
