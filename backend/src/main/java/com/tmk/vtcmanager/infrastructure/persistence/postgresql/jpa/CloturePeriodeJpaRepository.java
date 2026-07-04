package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CloturePeriodeEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CloturePeriodeJpaRepository extends JpaRepository<CloturePeriodeEntity, Long> {

    boolean existsByAnneeAndMois(int annee, int mois);

    Optional<CloturePeriodeEntity> findFirstByOrderByAnneeDescMoisDesc();

    List<CloturePeriodeEntity> findAllByOrderByAnneeDescMoisDesc();
}
