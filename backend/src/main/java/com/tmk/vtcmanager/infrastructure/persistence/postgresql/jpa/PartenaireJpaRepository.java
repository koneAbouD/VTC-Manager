package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PartenaireEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PartenaireJpaRepository extends JpaRepository<PartenaireEntity, Long> {

    List<PartenaireEntity> findByActifTrueOrderByNomAsc();

    List<PartenaireEntity> findAllByOrderByNomAsc();

    boolean existsByNomIgnoreCase(String nom);

    /** Un type encore porté par un partenaire ne peut plus être supprimé. */
    boolean existsByTypeId(Long typeId);
}
