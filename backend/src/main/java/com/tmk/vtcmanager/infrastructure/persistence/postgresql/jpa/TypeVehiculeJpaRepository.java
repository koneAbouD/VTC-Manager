package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeVehiculeEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TypeVehiculeJpaRepository extends JpaRepository<TypeVehiculeEntity, Long> {

    Optional<TypeVehiculeEntity> findByNom(String nom);

    List<TypeVehiculeEntity> findByActifTrueOrderByNomAsc();

    boolean existsByNom(String nom);
}
