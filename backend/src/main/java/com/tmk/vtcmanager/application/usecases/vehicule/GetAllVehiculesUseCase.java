package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllVehiculesUseCase {

    private static final int PRESIGNED_TTL = 3600;

    private final VehiculeRepository vehiculeRepository;
    private final VehiculePhotoRepository photoRepository;
    private final FileStoragePort storage;

    public List<Vehicule> execute() {
        return vehiculeRepository.findAll().stream()
                .map(v -> { v.setPhotos(photosWithUrls(v.getId())); return v; })
                .toList();
    }

    public PageResult<Vehicule> executePage(VehiculeStatus statut, int page, int size) {
        return vehiculeRepository.findPage(statut, page, size)
                .map(v -> { v.setPhotos(photosWithUrls(v.getId())); return v; });
    }

    private List<VehiculePhoto> photosWithUrls(Long vehiculeId) {
        return photoRepository.findByVehiculeId(vehiculeId).stream()
                .map(p -> { p.setUrl(storage.presignedUrl(p.getObjectName(), PRESIGNED_TTL)); return p; })
                .toList();
    }
}
