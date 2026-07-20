package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeActiviteEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TypeActiviteJpaRepository extends JpaRepository<TypeActiviteEntity, Long> {

    Optional<TypeActiviteEntity> findByNom(String nom);

    List<TypeActiviteEntity> findByActifTrueOrderByNomAsc();

    boolean existsByNom(String nom);
}