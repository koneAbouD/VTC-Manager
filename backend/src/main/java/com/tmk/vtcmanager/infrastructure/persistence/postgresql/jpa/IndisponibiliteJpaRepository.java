package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface IndisponibiliteJpaRepository extends JpaRepository<IndisponibiliteEntity, Long> {

    List<IndisponibiliteEntity> findByChauffeurIdOrderByDateDebutDesc(Long chauffeurId);

    List<IndisponibiliteEntity> findByStatut(IndisponibiliteStatut statut);

    @Query("""
            SELECT CASE WHEN COUNT(i) > 0 THEN true ELSE false END
            FROM IndisponibiliteEntity i
            WHERE i.chauffeur.id = :chauffeurId
              AND i.statut IN :statuts
              AND i.dateDebut <= :date
              AND (i.dateFin IS NULL OR i.dateFin >= :date)
            """)
    boolean isEnCongeAt(@Param("chauffeurId") Long chauffeurId,
                        @Param("date") LocalDate date,
                        @Param("statuts") List<IndisponibiliteStatut> statuts);
}
