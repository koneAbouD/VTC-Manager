package com.tmk.vtcmanager.application.usecases.sousCategorieOperation;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;

import java.util.Optional;

@RequiredArgsConstructor
public class GetAllSousCategoriesOperationUseCase {

    private final SousCategorieOperationRepository sousCategorieRepository;

    public Optional<SousCategorieOperation> execute(Long categorieId) {
        return sousCategorieRepository.findByCategorieId(categorieId);
    }
}
