package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;

import java.util.List;
import java.util.Optional;

public interface VehiculePhotoRepository {

    List<VehiculePhoto> findByVehiculeId(Long vehiculeId);

    VehiculePhoto save(VehiculePhoto photo, Long vehiculeId);

    Optional<VehiculePhoto> findByIdAndVehiculeId(Long id, Long vehiculeId);

    void deleteById(Long id);

    long countByVehiculeId(Long vehiculeId);
}
