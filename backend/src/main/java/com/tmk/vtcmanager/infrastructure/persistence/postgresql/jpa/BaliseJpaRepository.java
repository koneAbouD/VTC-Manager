package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.BaliseEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BaliseJpaRepository extends JpaRepository<BaliseEntity, Long> {

    Optional<BaliseEntity> findByIdentifiant(String identifiant);

    List<BaliseEntity> findByActifTrueOrderByIdentifiantAsc();

    boolean existsByIdentifiant(String identifiant);
}
