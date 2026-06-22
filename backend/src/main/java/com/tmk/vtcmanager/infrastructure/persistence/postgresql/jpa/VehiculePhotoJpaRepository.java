package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculePhotoEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VehiculePhotoJpaRepository extends JpaRepository<VehiculePhotoEntity, Long> {

    List<VehiculePhotoEntity> findByVehiculeIdOrderByOrdre(Long vehiculeId);

    long countByVehiculeId(Long vehiculeId);

    void deleteByIdAndVehiculeId(Long id, Long vehiculeId);
}
