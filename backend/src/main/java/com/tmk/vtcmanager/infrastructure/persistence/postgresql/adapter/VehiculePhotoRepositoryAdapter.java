package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculePhotoEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculePhotoJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class VehiculePhotoRepositoryAdapter implements VehiculePhotoRepository {

    private final VehiculePhotoJpaRepository photoJpa;
    private final VehiculeJpaRepository vehiculeJpa;

    @Override
    public List<VehiculePhoto> findByVehiculeId(Long vehiculeId) {
        return photoJpa.findByVehiculeIdOrderByOrdre(vehiculeId).stream()
                .map(this::toDomain)
                .toList();
    }

    @Override
    public VehiculePhoto save(VehiculePhoto photo, Long vehiculeId) {
        VehiculePhotoEntity entity = VehiculePhotoEntity.builder()
                .vehicule(vehiculeJpa.getReferenceById(vehiculeId))
                .objectName(photo.getObjectName())
                .ordre(photo.getOrdre())
                .build();
        return toDomain(photoJpa.save(entity));
    }

    @Override
    public Optional<VehiculePhoto> findByIdAndVehiculeId(Long id, Long vehiculeId) {
        return photoJpa.findById(id)
                .filter(p -> p.getVehicule().getId().equals(vehiculeId))
                .map(this::toDomain);
    }

    @Override
    public void deleteById(Long id) {
        photoJpa.deleteById(id);
    }

    @Override
    public long countByVehiculeId(Long vehiculeId) {
        return photoJpa.countByVehiculeId(vehiculeId);
    }

    private VehiculePhoto toDomain(VehiculePhotoEntity e) {
        return VehiculePhoto.builder()
                .id(e.getId())
                .objectName(e.getObjectName())
                .ordre(e.getOrdre())
                .build();
    }
}
