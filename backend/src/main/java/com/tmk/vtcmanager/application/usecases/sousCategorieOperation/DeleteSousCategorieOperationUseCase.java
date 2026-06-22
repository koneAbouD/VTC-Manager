package com.tmk.vtcmanager.application.usecases.sousCategorieOperation;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteSousCategorieOperationUseCase {

    private final SousCategorieOperationRepository sousCategorieRepository;

    @Transactional
    public void execute(Long id) {
        sousCategorieRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Sous-catégorie opération", id));
        sousCategorieRepository.deleteById(id);
    }
}
