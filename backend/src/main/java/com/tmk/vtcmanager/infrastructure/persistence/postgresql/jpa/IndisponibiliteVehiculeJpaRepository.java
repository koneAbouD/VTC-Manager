package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteVehiculeEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface IndisponibiliteVehiculeJpaRepository extends JpaRepository<IndisponibiliteVehiculeEntity, Long> {

    List<IndisponibiliteVehiculeEntity> findByVehiculeIdOrderByDateDebutDesc(Long vehiculeId);

    Page<IndisponibiliteVehiculeEntity> findByVehiculeId(Long vehiculeId, Pageable pageable);

    List<IndisponibiliteVehiculeEntity> findByStatut(IndisponibiliteStatut statut);

    @Query("""
            SELECT CASE WHEN COUNT(i) > 0 THEN true ELSE false END
            FROM IndisponibiliteVehiculeEntity i
            WHERE i.vehicule.id = :vehiculeId
              AND i.statut IN :statuts
              AND i.dateDebut <= :date
              AND (i.dateFin IS NULL OR i.dateFin >= :date)
            """)
    boolean isImmobiliseAt(@Param("vehiculeId") Long vehiculeId,
                           @Param("date") LocalDate date,
                           @Param("statuts") List<IndisponibiliteStatut> statuts);
}
