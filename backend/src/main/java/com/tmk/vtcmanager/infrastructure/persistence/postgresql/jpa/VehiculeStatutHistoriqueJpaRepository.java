package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculeStatutHistoriqueEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface VehiculeStatutHistoriqueJpaRepository extends JpaRepository<VehiculeStatutHistoriqueEntity, Long> {

    Optional<VehiculeStatutHistoriqueEntity> findByVehiculeIdAndDateFinIsNull(Long vehiculeId);

    List<VehiculeStatutHistoriqueEntity> findByDateFinIsNull();

    List<VehiculeStatutHistoriqueEntity> findByVehiculeIdOrderByDateDebutDesc(Long vehiculeId);
}
