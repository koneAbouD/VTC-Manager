package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.UUID;

@RequiredArgsConstructor
public class UploadVehiculePhotoUseCase {

    private static final int MAX_PHOTOS   = 4;
    private static final String PREFIX    = "vehicules/photos/";
    private static final int PRESIGNED_TTL = 3600;

    private final VehiculeRepository vehiculeRepository;
    private final VehiculePhotoRepository photoRepository;
    private final FileStoragePort storage;

    public VehiculePhoto execute(Long vehiculeId, MultipartFile file) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        long count = photoRepository.countByVehiculeId(vehiculeId);
        if (count >= MAX_PHOTOS) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,
                    "Un véhicule ne peut pas avoir plus de " + MAX_PHOTOS + " photos.");
        }

        String objectName = PREFIX + UUID.randomUUID() + "_" + file.getOriginalFilename();
        try {
            storage.upload(objectName, file.getInputStream(), file.getSize(), file.getContentType());
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Erreur lors de l'upload : " + e.getMessage());
        }

        VehiculePhoto photo = VehiculePhoto.builder()
                .objectName(objectName)
                .ordre((int) count)
                .build();
        VehiculePhoto saved = photoRepository.save(photo, vehiculeId);
        saved.setUrl(storage.presignedUrl(objectName, PRESIGNED_TTL));
        return saved;
    }
}
