package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConfigurationRecetteEntity;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ConfigurationRecetteJpaRepository extends JpaRepository<ConfigurationRecetteEntity, Long> {

    @EntityGraph(attributePaths = {"vehicule", "cotisations"})
    Optional<ConfigurationRecetteEntity> findByVehiculeId(Long vehiculeId);
}
