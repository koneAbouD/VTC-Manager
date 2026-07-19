package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeActiviteEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TypeActiviteJpaRepository extends JpaRepository<TypeActiviteEntity, Long> {

    Optional<TypeActiviteEntity> findByNom(String nom);

    boolean existsByNom(String nom);
}