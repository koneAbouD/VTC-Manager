package com.tmk.vtcmanager.application.usecases.sousCategorieOperation;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UpdateSousCategorieOperationUseCase {

    private final SousCategorieOperationRepository sousCategorieRepository;

    @Transactional
    public SousCategorieOperation execute(Long id, SousCategorieOperation data) {
        SousCategorieOperation existing = sousCategorieRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Sous-catégorie opération", id));
        existing.setLibelle(data.getLibelle());
        existing.setActif(data.isActif());
        return sousCategorieRepository.save(existing);
    }
}
