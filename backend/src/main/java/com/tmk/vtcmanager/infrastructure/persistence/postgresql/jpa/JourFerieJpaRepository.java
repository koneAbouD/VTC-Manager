package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.JourFerieEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface JourFerieJpaRepository extends JpaRepository<JourFerieEntity, Long> {

    List<JourFerieEntity> findByAnneeOrderByDateAsc(int annee);

    boolean existsByDate(LocalDate date);
}
