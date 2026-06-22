package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetCategorieOperationByIdUseCase {

    private final CategorieOperationRepository categorieRepository;
    private final SousCategorieOperationRepository sousCategorieRepository;

    public CategorieOperation execute(Long id, boolean includeSousCategorie) {
        CategorieOperation categorie = categorieRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Catégorie opération", id));

        if (includeSousCategorie) {
            categorie.setSousCategorie(sousCategorieRepository.findByCategorieId(id).orElse(null));
        }
        return categorie;
    }
}
