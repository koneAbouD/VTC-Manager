package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ClotureCaisseEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ClotureCaisseJpaRepository extends JpaRepository<ClotureCaisseEntity, Long> {

    boolean existsByCompteIdAndDateCloture(Long compteId, LocalDate dateCloture);

    List<ClotureCaisseEntity> findByCompteIdOrderByDateClotureDesc(Long compteId);
}
