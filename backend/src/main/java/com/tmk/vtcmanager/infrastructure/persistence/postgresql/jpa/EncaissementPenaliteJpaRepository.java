package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementPenaliteEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface EncaissementPenaliteJpaRepository extends JpaRepository<EncaissementPenaliteEntity, Long> {

    List<EncaissementPenaliteEntity> findByLignePenaliteId(Long lignePenaliteId);

    Optional<EncaissementPenaliteEntity> findByOperationFinanciereId(Long operationFinanciereId);
}
