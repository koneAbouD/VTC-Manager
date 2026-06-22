package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OperationFinanciereEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OperationFinanciereJpaRepository
        extends JpaRepository<OperationFinanciereEntity, Long>,
                JpaSpecificationExecutor<OperationFinanciereEntity> {

    List<OperationFinanciereEntity> findByChauffeurId(Long chauffeurId);

    List<OperationFinanciereEntity> findByVehiculeId(Long vehiculeId);

    boolean existsByReference(String reference);
}
