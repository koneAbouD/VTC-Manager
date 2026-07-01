package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllChauffeursUseCase {

    private static final int PRESIGNED_TTL = 3600;

    private final ChauffeurRepository chauffeurRepository;
    private final FileStoragePort fileStoragePort;

    public List<Chauffeur> execute() {
        return chauffeurRepository.findAll().stream()
                .map(this::withPresignedUrl)
                .toList();
    }

    public PageResult<Chauffeur> executePage(ChauffeurStatus statut, int page, int size) {
        return chauffeurRepository.findPage(statut, page, size).map(this::withPresignedUrl);
    }

    private Chauffeur withPresignedUrl(Chauffeur chauffeur) {
        if (chauffeur.getPhotoUrl() != null && !chauffeur.getPhotoUrl().isBlank()) {
            chauffeur.setPhotoPresignedUrl(
                    fileStoragePort.presignedUrl(chauffeur.getPhotoUrl(), PRESIGNED_TTL));
        }
        return chauffeur;
    }
}
