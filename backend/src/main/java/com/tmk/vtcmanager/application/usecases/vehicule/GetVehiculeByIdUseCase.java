package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetVehiculeByIdUseCase {

    private static final int PRESIGNED_TTL = 3600;

    private final VehiculeRepository vehiculeRepository;
    private final VehiculePhotoRepository photoRepository;
    private final FileStoragePort storage;

    public Vehicule execute(Long id) {
        Vehicule vehicule = vehiculeRepository.findById(id)
                .orElseThrow(() -> new VehiculeNotFoundException(id));
        vehicule.setPhotos(photosWithUrls(id));
        return vehicule;
    }

    private List<VehiculePhoto> photosWithUrls(Long vehiculeId) {
        return photoRepository.findByVehiculeId(vehiculeId).stream()
                .map(p -> { p.setUrl(storage.presignedUrl(p.getObjectName(), PRESIGNED_TTL)); return p; })
                .toList();
    }
}
