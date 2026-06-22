package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteCategorieOperationUseCase {

    private final CategorieOperationRepository categorieRepository;

    @Transactional
    public void execute(Long id) {
        categorieRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Catégorie opération", id));
        categorieRepository.deleteById(id);
    }
}
