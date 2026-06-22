package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllCategoriesOperationUseCase {

    private final CategorieOperationRepository categorieRepository;
    private final SousCategorieOperationRepository sousCategorieRepository;

    public List<CategorieOperation> execute(TypeOperation typeOperation, String sousCategorieCode,
                                            String sousCategorieLibelle, boolean includeSousCategorie) {
        List<CategorieOperation> categories;

        if (sousCategorieLibelle != null && !sousCategorieLibelle.isBlank()) {
            categories = categorieRepository.findBySousCategorieLibelle(sousCategorieLibelle);
        } else if (sousCategorieCode != null && !sousCategorieCode.isBlank()) {
            categories = categorieRepository.findBySousCategorieCode(sousCategorieCode);
        } else if (typeOperation != null) {
            categories = categorieRepository.findByTypeOperation(typeOperation);
        } else {
            categories = categorieRepository.findAll();
        }

        if (includeSousCategorie) {
            categories.forEach(cat ->
                cat.setSousCategorie(
                        sousCategorieRepository.findByCategorieId(cat.getId()).orElse(null))
            );
        }
        return categories;
    }
}
