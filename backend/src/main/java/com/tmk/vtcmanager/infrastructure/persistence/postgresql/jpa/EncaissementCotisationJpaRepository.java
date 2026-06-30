package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface EncaissementCotisationJpaRepository extends JpaRepository<EncaissementCotisationEntity, Long> {

    @EntityGraph(attributePaths = {"ligneCotisation", "operationFinanciere"})
    Optional<EncaissementCotisationEntity> findById(Long id);

    List<EncaissementCotisationEntity> findByLigneCotisationId(Long ligneCotisationId);

    Optional<EncaissementCotisationEntity> findByOperationFinanciereId(Long operationFinanciereId);
}
