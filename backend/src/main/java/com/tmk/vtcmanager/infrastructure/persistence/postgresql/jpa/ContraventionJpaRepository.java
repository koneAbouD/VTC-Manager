package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ContraventionEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ContraventionJpaRepository extends JpaRepository<ContraventionEntity, Long> {

    List<ContraventionEntity> findByChauffeurId(Long chauffeurId);

    List<ContraventionEntity> findByVehiculeId(Long vehiculeId);

    List<ContraventionEntity> findByStatut(ContraventionStatus statut);

    List<ContraventionEntity> findByChauffeurIdOrderByCreatedAtDesc(Long chauffeurId);

    List<ContraventionEntity> findByVehiculeIdOrderByCreatedAtDesc(Long vehiculeId);
}
