package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypePartenaireEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TypePartenaireJpaRepository extends JpaRepository<TypePartenaireEntity, Long> {

    Optional<TypePartenaireEntity> findByNomIgnoreCase(String nom);

    List<TypePartenaireEntity> findAllByOrderByNomAsc();

    List<TypePartenaireEntity> findByActifTrueOrderByNomAsc();

    boolean existsByNomIgnoreCase(String nom);
}
