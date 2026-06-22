package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateCategorieOperationUseCase {

    private final CategorieOperationRepository categorieRepository;

    @Transactional
    public CategorieOperation execute(CategorieOperation categorie) {
        if (categorieRepository.existsByCode(categorie.getCode())) {
            throw new ResourceAlreadyExistsException("Une catégorie avec le code '" + categorie.getCode() + "' existe déjà.");
        }
        categorie.setActif(true);
        return categorieRepository.save(categorie);
    }
}
