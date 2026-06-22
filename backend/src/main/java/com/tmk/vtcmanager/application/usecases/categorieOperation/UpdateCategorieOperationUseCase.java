package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UpdateCategorieOperationUseCase {

    private final CategorieOperationRepository categorieRepository;

    @Transactional
    public CategorieOperation execute(Long id, CategorieOperation data) {
        CategorieOperation existing = categorieRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Catégorie opération", id));
        existing.setLibelle(data.getLibelle());
        existing.setTypeOperation(data.getTypeOperation());
        existing.setActif(data.isActif());
        return categorieRepository.save(existing);
    }
}
