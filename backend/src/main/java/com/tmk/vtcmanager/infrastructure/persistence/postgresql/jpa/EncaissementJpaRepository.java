package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface EncaissementJpaRepository extends JpaRepository<EncaissementEntity, Long> {

    @EntityGraph(attributePaths = {"ligneRecette", "operationFinanciere"})
    Optional<EncaissementEntity> findById(Long id);

    List<EncaissementEntity> findByLigneRecetteId(Long ligneRecetteId);

    Optional<EncaissementEntity> findByOperationFinanciereId(Long operationFinanciereId);
}
