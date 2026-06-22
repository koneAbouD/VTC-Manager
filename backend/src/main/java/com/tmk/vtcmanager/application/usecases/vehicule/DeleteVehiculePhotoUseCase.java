package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@RequiredArgsConstructor
public class DeleteVehiculePhotoUseCase {

    private final VehiculePhotoRepository photoRepository;
    private final FileStoragePort storage;

    public void execute(Long vehiculeId, Long photoId) {
        VehiculePhoto photo = photoRepository.findByIdAndVehiculeId(photoId, vehiculeId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo introuvable."));
        storage.delete(photo.getObjectName());
        photoRepository.deleteById(photoId);
    }
}
