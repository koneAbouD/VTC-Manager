package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetChauffeurByIdUseCase {

    private static final int PRESIGNED_TTL = 3600;

    private final ChauffeurRepository chauffeurRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final FileStoragePort storage;

    public record Result(Chauffeur chauffeur, ProgrammeTravail programmeTravail) {}

    public Result execute(Long id) {
        Chauffeur chauffeur = chauffeurRepository.findById(id)
                .orElseThrow(() -> new ChauffeurNotFoundException(id));

        if (chauffeur.getPhotoUrl() != null && !chauffeur.getPhotoUrl().isBlank()) {
            chauffeur.setPhotoPresignedUrl(
                    storage.presignedUrl(chauffeur.getPhotoUrl(), PRESIGNED_TTL));
        }

        ProgrammeTravail programme = programmeTravailRepository
                .findByChauffeurId(id)
                .orElse(null);

        return new Result(chauffeur, programme);
    }
}
