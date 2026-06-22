package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MarqueEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface MarqueJpaRepository extends JpaRepository<MarqueEntity, Long> {

    Optional<MarqueEntity> findByNom(String nom);

    boolean existsByNom(String nom);
}
