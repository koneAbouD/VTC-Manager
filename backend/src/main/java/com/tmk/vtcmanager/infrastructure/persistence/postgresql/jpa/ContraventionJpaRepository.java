package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ContraventionEntity;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ContraventionJpaRepository
        extends JpaRepository<ContraventionEntity, Long>,
                JpaSpecificationExecutor<ContraventionEntity> {

    List<ContraventionEntity> findByChauffeurId(Long chauffeurId, Sort sort);

    List<ContraventionEntity> findByVehiculeId(Long vehiculeId, Sort sort);

    List<ContraventionEntity> findByStatut(ContraventionStatus statut);

    boolean existsByNumeroContravention(String numeroContravention);

    Optional<ContraventionEntity> findByNumeroContravention(String numeroContravention);
}
